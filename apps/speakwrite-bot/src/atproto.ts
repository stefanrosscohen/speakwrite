import { AtpAgent } from '@atproto/api';
import { PostTarget, ProofRecord } from './types.js';

/** Parse an AT URI into { repo, collection, rkey } */
export function parseAtUri(uri: string) {
  const match = uri.match(/^at:\/\/([^/]+)\/([^/]+)\/([^/]+)$/);
  if (!match) throw new Error(`Invalid AT URI: ${uri}`);
  return { repo: match[1], collection: match[2], rkey: match[3] };
}

/** Resolve a mention notification to the post we should verify.
 *  If the mention is a reply, verify the parent post. Otherwise verify the mention itself. */
export async function resolvePostTarget(
  agent: AtpAgent,
  mentionUri: string,
  mentionCid: string,
  mentionRecord: {
    text: string;
    reply?: { parent: { uri: string; cid: string }; root: { uri: string; cid: string } };
  },
  mentionAuthorDid: string,
  mentionAuthorHandle: string
): Promise<PostTarget> {
  // If the mention is a reply, verify the parent post
  if (mentionRecord.reply?.parent) {
    const parentUri = mentionRecord.reply.parent.uri;
    const { repo, rkey } = parseAtUri(parentUri);

    const res = await agent.app.bsky.feed.getPosts({ uris: [parentUri] });
    const post = res.data.posts[0];
    if (!post) throw new Error(`Could not fetch parent post: ${parentUri}`);

    return {
      uri: post.uri,
      cid: post.cid,
      authorDid: post.author.did,
      text: (post.record as { text: string }).text,
      handle: post.author.handle,
      rkey,
    };
  }

  // Otherwise verify the mention post itself
  const { rkey } = parseAtUri(mentionUri);
  return {
    uri: mentionUri,
    cid: mentionCid,
    authorDid: mentionAuthorDid,
    text: mentionRecord.text,
    handle: mentionAuthorHandle,
    rkey,
  };
}

/** Fetch with timeout */
async function fetchWithTimeout(url: string, timeoutMs = 10000): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

/** Resolve a DID to its PDS endpoint via plc.directory */
async function resolvePds(did: string): Promise<string> {
  const resp = await fetchWithTimeout(`https://plc.directory/${encodeURIComponent(did)}`);
  if (!resp.ok) throw new Error(`Could not resolve DID: ${did}`);
  const didDoc = await resp.json();
  const pds = didDoc.service?.find(
    (s: { id: string; serviceEndpoint: string }) => s.id === '#atproto_pds'
  )?.serviceEndpoint;
  if (!pds) throw new Error(`No PDS found for DID: ${did}`);

  // Validate PDS URL to prevent SSRF
  if (!pds.startsWith('https://')) {
    throw new Error('PDS endpoint must use HTTPS');
  }
  const parsedUrl = new URL(pds);
  if (parsedUrl.hostname === 'localhost' || parsedUrl.hostname.startsWith('127.') || parsedUrl.hostname === '0.0.0.0') {
    throw new Error('PDS endpoint cannot be a local address');
  }

  return pds;
}

/** Fetch the Speakwrite proof record for a given post.
 *  Returns the proof record if found, null if no proof exists.
 *  Throws on network/server errors so callers can distinguish "no proof" from "couldn't check". */
export async function fetchProofForPost(
  postUri: string,
  authorDid: string
): Promise<ProofRecord | null> {
  const pds = await resolvePds(authorDid);
  let cursor: string | undefined;

  const MAX_PAGES = 50;
  let pages = 0;

  do {
    const url = new URL(`${pds}/xrpc/com.atproto.repo.listRecords`);
    url.searchParams.set('repo', authorDid);
    url.searchParams.set('collection', 'io.speakwrite.proof');
    url.searchParams.set('limit', '100');
    // Newest-first (default order): the post being verified is almost always
    // recent, so it's found on page one instead of after walking the entire
    // proof history oldest-first.
    if (cursor) url.searchParams.set('cursor', cursor);

    const resp = await fetchWithTimeout(url.toString());
    if (!resp.ok) {
      throw new Error(`PDS returned ${resp.status} when fetching proof records`);
    }

    const data = await resp.json();
    const record = data.records?.find(
      (r: { value: ProofRecord }) => r.value?.postUri === postUri
    );
    if (record) return record.value;

    cursor = data.cursor;
    pages++;
  } while (cursor && pages < MAX_PAGES);

  return null;
}
