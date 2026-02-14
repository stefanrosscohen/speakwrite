/**
 * Public Bluesky API client.
 * No auth required — uses public.api.bsky.app for unauthenticated reads.
 */

const PUBLIC_API = "https://public.api.bsky.app";

/* ----------------------------------------------------------------
   Types
   ---------------------------------------------------------------- */

export interface BlueskyAuthor {
  did: string;
  handle: string;
  displayName?: string;
  avatar?: string;
}

export interface BlueskyPostRecord {
  text: string;
  createdAt: string;
  $type?: string;
}

export interface BlueskyPost {
  uri: string;
  cid: string;
  author: BlueskyAuthor;
  record: BlueskyPostRecord;
  indexedAt: string;
}

export interface SearchPostsResponse {
  posts: BlueskyPost[];
  cursor?: string;
}

export interface AuthorFeedResponse {
  feed: Array<{ post: BlueskyPost }>;
  cursor?: string;
}

/* ----------------------------------------------------------------
   API calls
   ---------------------------------------------------------------- */

/**
 * Search for posts likely to be Speakwrite posts.
 * Uses keyword search; results are further filtered client-side by regex.
 */
export async function searchSpeakwritePosts(
  cursor?: string,
): Promise<SearchPostsResponse> {
  const params = new URLSearchParams({
    q: '"keystrokes" "commitments"',
    limit: "25",
    sort: "latest",
  });
  if (cursor) params.set("cursor", cursor);

  const res = await fetch(
    `${PUBLIC_API}/xrpc/app.bsky.feed.searchPosts?${params}`,
  );
  if (!res.ok) throw new Error(`Search failed: ${res.status}`);
  return res.json();
}

/**
 * Get a specific user's feed. We filter client-side for Speakwrite posts.
 */
export async function getAuthorFeed(
  actor: string,
  cursor?: string,
): Promise<AuthorFeedResponse> {
  const params = new URLSearchParams({ actor, limit: "50" });
  if (cursor) params.set("cursor", cursor);

  const res = await fetch(
    `${PUBLIC_API}/xrpc/app.bsky.feed.getAuthorFeed?${params}`,
  );
  if (!res.ok) throw new Error(`Feed fetch failed: ${res.status}`);
  return res.json();
}

/**
 * Resolve a DID to a PDS endpoint.
 * Supports did:plc (via plc.directory) and did:web.
 */
export async function resolvePdsEndpoint(did: string): Promise<string> {
  if (did.startsWith("did:plc:")) {
    const res = await fetch(
      `https://plc.directory/${encodeURIComponent(did)}`,
    );
    if (!res.ok) throw new Error(`PLC lookup failed: ${res.status}`);
    const doc = await res.json();
    const pds = doc.service?.find(
      (s: { id: string; type: string; serviceEndpoint: string }) =>
        s.id === "#atproto_pds" || s.type === "AtprotoPersonalDataServer",
    );
    if (!pds?.serviceEndpoint) throw new Error("No PDS in DID document");
    return pds.serviceEndpoint;
  }

  if (did.startsWith("did:web:")) {
    const domain = did.replace("did:web:", "").replace(/:/g, "/");
    const res = await fetch(`https://${domain}/.well-known/did.json`);
    if (!res.ok) throw new Error(`did:web lookup failed: ${res.status}`);
    const doc = await res.json();
    const pds = doc.service?.find(
      (s: { id: string; type: string; serviceEndpoint: string }) =>
        s.id === "#atproto_pds" || s.type === "AtprotoPersonalDataServer",
    );
    if (!pds?.serviceEndpoint) throw new Error("No PDS in DID document");
    return pds.serviceEndpoint;
  }

  throw new Error(`Unsupported DID method: ${did}`);
}

/**
 * Attempt to fetch io.speakwrite.proof records from a user's PDS.
 * Returns the records array, or null on failure.
 */
export async function fetchProofRecords(
  did: string,
): Promise<Array<{ uri: string; value: Record<string, unknown> }> | null> {
  try {
    const pds = await resolvePdsEndpoint(did);
    const res = await fetch(
      `${pds}/xrpc/com.atproto.repo.listRecords?repo=${encodeURIComponent(did)}&collection=io.speakwrite.proof&limit=50`,
    );
    if (!res.ok) return null;
    const data = await res.json();
    return data.records ?? null;
  } catch {
    return null;
  }
}

/**
 * Extract the rkey (record key) from an AT URI.
 * e.g., at://did:plc:xxx/app.bsky.feed.post/3abc → "3abc"
 */
export function rkeyFromUri(uri: string): string {
  return uri.split("/").pop() ?? "";
}
