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

/** Resolve a DID to its PDS endpoint via plc.directory */
async function resolvePds(did: string): Promise<string> {
  const resp = await fetch(`https://plc.directory/${encodeURIComponent(did)}`);
  if (!resp.ok) throw new Error(`Could not resolve DID: ${did}`);
  const didDoc = await resp.json();
  const pds = didDoc.service?.find(
    (s: { id: string; serviceEndpoint: string }) => s.id === '#atproto_pds'
  )?.serviceEndpoint;
  if (!pds) throw new Error(`No PDS found for DID: ${did}`);
  return pds;
}

/** Fetch the Speakwrite proof record for a given post */
export async function fetchProofForPost(
  postUri: string,
  authorDid: string
): Promise<ProofRecord | null> {
  const pds = await resolvePds(authorDid);

  const resp = await fetch(
    `${pds}/xrpc/com.atproto.repo.listRecords?repo=${encodeURIComponent(
      authorDid
    )}&collection=io.speakwrite.proof&limit=100`
  );
  if (!resp.ok) return null;

  const data = await resp.json();
  const record = data.records?.find(
    (r: { value: ProofRecord }) => r.value?.postUri === postUri
  );

  return record?.value ?? null;
}
