import { AtpAgent, RichText } from '@atproto/api';
import Anthropic from '@anthropic-ai/sdk';
import { resolvePostTarget, fetchProofForPost, parseAtUri } from './atproto.js';
import { verifyPost } from './verify.js';
import { PostTarget } from './types.js';

// LRU-style dedup: cap at 10,000 entries, evict oldest when full
const MAX_PROCESSED = 10_000;
const processedUris = new Set<string>();

function trackProcessed(uri: string) {
  processedUris.add(uri);
  if (processedUris.size > MAX_PROCESSED) {
    // Delete the oldest entry (Sets iterate in insertion order)
    const oldest = processedUris.values().next().value;
    if (oldest) processedUris.delete(oldest);
  }
}

const anthropic = new Anthropic();

function pick<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

/** Truncate text to fit within Bluesky's 300-grapheme limit, accounting for byte length. */
function truncateForBluesky(text: string, maxGraphemes = 300): string {
  const segmenter = new Intl.Segmenter('en', { granularity: 'grapheme' });
  const segments = [...segmenter.segment(text)];
  if (segments.length <= maxGraphemes) return text;
  return segments.slice(0, maxGraphemes - 1).map(s => s.segment).join('') + '…';
}

/** Small delay between replies to avoid rate limiting */
function delay(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

const REPLY_SYSTEM_PROMPT = `You are the Speakwrite verification bot on Bluesky. You just cryptographically verified that a post was genuinely typed by a human on a real Apple device using the Secure Enclave.

Your job: write a short, funny, one-liner reply confirming the verification. You should:
- Be witty, playful, and a little snarky
- Reference the CONTEXT — what the post says, what the person who tagged you said, the vibe of the conversation
- Always make it clear the post is VERIFIED as human-written
- Keep it under 200 characters (this is for Bluesky)
- Don't use hashtags
- Don't start with "✓" (that gets prepended automatically)
- Never explain what Speakwrite is in detail
- Vary your style — sometimes deadpan, sometimes enthusiastic, sometimes sarcastic

Examples of the TONE (don't copy these, just match the energy):
- "Yep, that's a real human. The Secure Enclave doesn't lie."
- "The math checks out. A flesh-and-blood person actually typed this."
- "ECDSA verification passed. This post has more proof of humanity than most dating profiles."`;

const NO_PROOF_SYSTEM_PROMPT = `You are the Speakwrite verification bot on Bluesky. You just checked a post for cryptographic proof of human authorship — and found NONE.

Your job: write a short, funny, one-liner noting the lack of proof. You should:
- Be witty, playful, and a little suspicious (but not accusatory)
- Reference the CONTEXT — what the post says, what the person who tagged you said
- Make it clear there's NO Speakwrite proof for this post (but don't definitively say it's AI)
- Keep it under 200 characters (this is for Bluesky)
- Don't use hashtags
- Vary your style — sometimes deadpan, sometimes sarcastic, sometimes conspiratorial

Examples of the TONE (don't copy these, just match the energy):
- "No proof on file. Could be human, could be a mass of LLM tokens in a trenchcoat."
- "Zero proof records found. This post is flying without a license."
- "No Speakwrite proof. For all we know, this was written by a very articulate toaster."`;

const FAILED_SYSTEM_PROMPT = `You are the Speakwrite verification bot on Bluesky. You found a proof record for a post but the cryptographic verification FAILED.

Your job: write a short, funny, one-liner about the failed verification. You should:
- Be witty and a bit alarmed
- Reference the CONTEXT if possible
- Make it clear the proof didn't check out
- Keep it under 200 characters (this is for Bluesky)
- Don't use hashtags
- Vary your style

Examples of the TONE (don't copy these, just match the energy):
- "Yikes — verification failed. The math didn't math."
- "This proof didn't pass the vibe check (or the ECDSA check)."`;

const CHAT_SYSTEM_PROMPT = `You are the Speakwrite verification bot on Bluesky. Someone tagged you but NOT on a post to verify — they're just trying to chat or interact with you.

Your job: write a short, funny reply. You should:
- Be witty and self-aware that you're a single-purpose verification bot
- Gently redirect them to tag you on an actual post if they want to see you work
- Keep it under 250 characters
- Don't use hashtags
- Reference what they said if possible

Examples of the TONE (don't copy these, just match the energy):
- "I'm a verification bot, not a conversationalist. But I appreciate the effort."
- "My therapist says I need to develop interests outside of cryptographic verification. I haven't listened."
- "Sorry, I'm a one-trick pony and that trick is P-256 ECDSA signature verification."`;

/** Generate a reply using Claude */
async function generateReply(
  systemPrompt: string,
  postText: string,
  mentionText: string
): Promise<string> {
  try {
    const userMessage = `Post being verified: "${postText}"\n\nWhat the person who tagged me said: "${mentionText}"\n\nWrite your reply:`;

    const response = await anthropic.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 150,
      system: systemPrompt,
      messages: [{ role: 'user', content: userMessage }],
    });

    const text = response.content[0];
    if (text.type === 'text') {
      // Strip quotes if Claude wraps the response
      return text.text.replace(/^["']|["']$/g, '').trim();
    }
    throw new Error('Unexpected response format');
  } catch (err) {
    console.error('Claude API error, using fallback:', err);
    return '';
  }
}

// ── Fallback lines (used when Claude API fails) ──
const VERIFIED_FALLBACK = [
  "Verified. A real human typed this on a real Apple device.",
  "The cryptography checks out. Certified human post.",
  "Confirmed human. The Secure Enclave vouches for this one.",
];
const NO_PROOF_FALLBACK = [
  "No Speakwrite proof found for this post. Most posts don't use Speakwrite — that's fine.",
  "No proof on file. This post wasn't published through Speakwrite.",
  "No Speakwrite proof. This just means the post wasn't made with the Speakwrite app.",
];
const FAILED_FALLBACK = [
  "Verification failed. The math didn't math.",
  "This proof didn't pass the vibe check. Something's off.",
];
const CHAT_FALLBACK = [
  "I verify posts! Reply to any post with @speakwrite-bot and I'll check if it has a Speakwrite proof.",
  "I'm a verification bot — reply to a post and mention me to check if it's human-verified via Speakwrite.",
];


/** Check if we already replied to a post in its thread.
 *  Returns 'yes' | 'no' | 'unknown' (network error — caller decides). */
async function alreadyReplied(
  agent: AtpAgent,
  targetUri: string,
  botDid: string
): Promise<'yes' | 'no' | 'unknown'> {
  try {
    const thread = await agent.app.bsky.feed.getPostThread({
      uri: targetUri,
      depth: 1,
    });
    const replies = (thread.data.thread as { replies?: Array<{ post: { author: { did: string } } }> }).replies;
    if (!replies) return 'no';
    return replies.some((r) => r.post?.author?.did === botDid) ? 'yes' : 'no';
  } catch {
    return 'unknown';
  }
}

type Facet = {
  index: { byteStart: number; byteEnd: number };
  features: Array<{ $type: string; uri: string }>;
};

/** Build a reply with a link facet, using Claude for the response text */
async function buildReplyText(
  verified: boolean,
  target: PostTarget,
  reason?: string,
  mentionText?: string
): Promise<{ text: string; facets: Facet[] }> {
  const linkUrl = `https://www.speakwrite.io/verify/${encodeURIComponent(target.handle)}/${encodeURIComponent(target.rkey)}`;

  let line1: string;

  if (verified) {
    const generated = await generateReply(
      REPLY_SYSTEM_PROMPT,
      target.text,
      mentionText || ''
    );
    line1 = '✓ ' + (generated || pick(VERIFIED_FALLBACK));
  } else if (reason) {
    const generated = await generateReply(
      FAILED_SYSTEM_PROMPT,
      target.text,
      mentionText || ''
    );
    line1 = generated || pick(FAILED_FALLBACK);
  } else {
    const generated = await generateReply(
      NO_PROOF_SYSTEM_PROMPT,
      target.text,
      mentionText || ''
    );
    line1 = generated || pick(NO_PROOF_FALLBACK);
  }

  const linkLabel = verified ? 'Verify independently →' : 'Check for yourself →';
  const linkText = `www.speakwrite.io/verify/${encodeURIComponent(target.handle)}/${encodeURIComponent(target.rkey)}`;
  const suffix = `\n\n${linkLabel}\n${linkText}`;

  // Truncate line1 to fit within 300 graphemes (reserving space for the link)
  const suffixGraphemes = [...new Intl.Segmenter('en', { granularity: 'grapheme' }).segment(suffix)].length;
  line1 = truncateForBluesky(line1, 300 - suffixGraphemes);

  const text = `${line1}${suffix}`;

  // Compute byte offsets AFTER final text is assembled
  const linkByteStart = Buffer.byteLength(`${line1}\n\n`, 'utf8');
  const linkByteEnd = linkByteStart + Buffer.byteLength(linkLabel, 'utf8');

  return {
    text,
    facets: [
      {
        index: { byteStart: linkByteStart, byteEnd: linkByteEnd },
        features: [{ $type: 'app.bsky.richtext.facet#link', uri: linkUrl }],
      },
    ],
  };
}

/** Check if mention is a verification request (reply to another post) or just casual interaction */
function isVerificationRequest(record: {
  text: string;
  reply?: { parent: { uri: string; cid: string } };
}): boolean {
  return !!record.reply?.parent;
}

/** Poll for new mentions and respond */
export async function pollNotifications(agent: AtpAgent): Promise<void> {
  try {
    const botDid = agent.session?.did;
    if (!botDid) {
      console.error('Not logged in');
      return;
    }

    // Paginate through all unread notifications to avoid missing any
    type Notification = Awaited<ReturnType<typeof agent.listNotifications>>['data']['notifications'][number];
    const mentions: Notification[] = [];
    let notifCursor: string | undefined;
    let foundRead = false;
    let sawUnread = false;
    while (!foundRead) {
      const res = await agent.listNotifications({ limit: 50, cursor: notifCursor });
      const notifications = res.data.notifications;
      for (const n of notifications) {
        if (n.isRead) { foundRead = true; break; }
        sawUnread = true;
        if (n.reason === 'mention') mentions.push(n);
      }
      if (notifications.length < 50) break;
      notifCursor = res.data.cursor;
      if (!notifCursor) break;
    }

    if (mentions.length === 0) {
      // Still mark likes/follows/replies as seen — otherwise the unread
      // backlog grows forever and every 30s poll re-walks all of it.
      if (sawUnread) {
        await agent.updateSeenNotifications();
      }
      return;
    }

    console.log(`Processing ${mentions.length} mention(s)...`);

    for (const mention of mentions) {
      const mentionUri = mention.uri;

      // Dedup within process
      if (processedUris.has(mentionUri)) continue;
      trackProcessed(mentionUri);

      try {
        const record = mention.record as {
          text: string;
          reply?: {
            parent: { uri: string; cid: string };
            root: { uri: string; cid: string };
          };
        };

        const replyRef = {
          root: record.reply?.root ?? { uri: mentionUri, cid: mention.cid },
          parent: { uri: mentionUri, cid: mention.cid },
        };

        // If not a reply to another post, it's casual interaction
        if (!isVerificationRequest(record)) {
          const chatDedup = await alreadyReplied(agent, mentionUri, botDid);
          if (chatDedup !== 'no') continue; // skip if already replied or uncertain

          const chatReply = await generateReply(
            CHAT_SYSTEM_PROMPT,
            '',
            record.text
          );
          await agent.post({
            text: truncateForBluesky(chatReply || pick(CHAT_FALLBACK)),
            reply: replyRef,
          });
          console.log(`Chat reply to ${mentionUri}`);
          await delay(1000);
          continue;
        }

        // Resolve what post to verify
        const target = await resolvePostTarget(
          agent,
          mentionUri,
          mention.cid,
          record,
          mention.author.did,
          mention.author.handle
        );

        // Check if we already replied (dedup across restarts). The bot's reply
        // is posted as a child of the *mention*, so that's where it must look —
        // checking the target post misses our reply and duplicates on restart.
        const dedup = await alreadyReplied(agent, mentionUri, botDid);
        if (dedup !== 'no') {
          console.log(`Already replied or uncertain for ${target.uri}, skipping`);
          continue;
        }

        // Fetch proof (throws on network errors, returns null if no proof exists)
        let proof: Awaited<ReturnType<typeof fetchProofForPost>> = null;
        let networkError = false;
        try {
          proof = await fetchProofForPost(target.uri, target.authorDid);
        } catch (fetchErr) {
          console.error(`Network error fetching proof for ${target.uri}:`, fetchErr);
          networkError = true;
        }

        if (networkError) {
          await agent.post({
            text: truncateForBluesky("I tried to check this post but couldn't reach the author's server. Try again in a bit!"),
            reply: replyRef,
          });
          console.log(`Network error reply for ${mentionUri}`);
          await delay(1000);
          continue;
        }

        let verified = false;
        let reason: string | undefined;

        if (proof) {
          const result = await verifyPost(target.text, proof);
          verified = result.verified;
          reason = result.reason;
        }

        // Build reply
        const reply = await buildReplyText(verified, target, proof ? reason : undefined, record.text);

        // Text is already truncated in buildReplyText — don't re-truncate
        // (which would invalidate facet byte offsets)
        await agent.post({
          text: reply.text,
          facets: reply.facets,
          reply: replyRef,
        });

        console.log(
          `Replied to ${mentionUri}: ${verified ? 'verified' : proof ? `failed: ${reason}` : 'no proof'}`
        );
        await delay(1000);
      } catch (err) {
        console.error(`Error processing mention ${mentionUri}:`, err);
      }
    }

    // Mark all as seen
    await agent.updateSeenNotifications();
  } catch (err) {
    console.error('Error polling notifications:', err);
  }
}
