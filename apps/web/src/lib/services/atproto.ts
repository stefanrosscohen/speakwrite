import { BrowserOAuthClient } from "@atproto/oauth-client-browser";
import { Agent } from "@atproto/api";
import type { ProofBundle } from "@speakwrite/core";

const IS_DEV = import.meta.env.DEV;

const oauthClient = new BrowserOAuthClient({
  handleResolver: "https://bsky.social",
  clientMetadata: IS_DEV
    ? undefined
    : {
        client_id: "https://speakwrite.io/app/client-metadata.json",
        client_name: "Speakwrite",
        client_uri: "https://speakwrite.io",
        redirect_uris: ["https://speakwrite.io/app/"],
        scope: "atproto",
        grant_types: ["authorization_code", "refresh_token"],
        response_types: ["code"],
        token_endpoint_auth_method: "none",
        application_type: "web",
        dpop_bound_access_tokens: true,
      },
});

let agent: Agent | null = null;

export function getAgent(): Agent | null {
  return agent;
}

/**
 * Called on page load. Handles OAuth callback (if returning from PDS auth page)
 * or restores an existing session from IndexedDB.
 */
export async function initOAuth(): Promise<{
  did: string;
  handle: string;
} | null> {
  const result = await oauthClient.init();

  if (result) {
    const { session } = result;
    agent = new Agent(session);

    // Resolve handle from DID
    const profile = await agent.getProfile({ actor: session.did });

    return {
      did: session.did,
      handle: profile.data.handle,
    };
  }

  return null;
}

/**
 * Initiates OAuth sign-in. Redirects the browser to the user's PDS auth page.
 * This promise never resolves — the page navigates away.
 */
export async function signIn(handle: string): Promise<void> {
  await oauthClient.signIn(handle, {
    state: crypto.randomUUID(),
  });
}

/**
 * Clears the current agent and any legacy session data.
 */
export async function logout(): Promise<void> {
  agent = null;
  // Clean up legacy app-password session data from Dexie
  try {
    const { db } = await import("../db");
    await db.settings.delete("atproto_session");
  } catch {
    // ignore
  }
}

/**
 * Registers a listener for session deletion events (e.g., token revoked).
 * Returns a cleanup function.
 */
export function onSessionDeleted(callback: () => void): () => void {
  const handler = () => {
    agent = null;
    callback();
  };
  oauthClient.addEventListener("deleted", handler);
  return () => oauthClient.removeEventListener("deleted", handler);
}

export async function publishProofRecord(
  bundle: ProofBundle,
  verifierBaseUrl: string = "https://verify.speakwrite.io",
): Promise<{ uri: string; cid: string }> {
  if (!agent?.did) throw new Error("Not logged in to AT Protocol");

  const record = {
    $type: "io.speakwrite.proof",
    contentHash: bundle.content_hash,
    bindingHash: bundle.binding_hash,
    chainLength: bundle.commitments.length,
    totalKeystrokes: bundle.total_keystroke_count,
    proofBundle: JSON.stringify(bundle),
    verifierUrl: `${verifierBaseUrl}?bundle=${encodeURIComponent(JSON.stringify(bundle))}`,
    createdAt: new Date().toISOString(),
  };

  const response = await agent.com.atproto.repo.createRecord({
    repo: agent.did,
    collection: "io.speakwrite.proof",
    record,
  });

  return { uri: response.data.uri, cid: response.data.cid };
}

export async function publishProofPost(
  bundle: ProofBundle,
  title: string = "Untitled",
  verifierBaseUrl: string = "https://verify.speakwrite.io",
): Promise<{ uri: string; cid: string }> {
  if (!agent?.did) throw new Error("Not logged in to AT Protocol");

  const verifierUrl = `${verifierBaseUrl}?bundle=${encodeURIComponent(JSON.stringify(bundle))}`;
  const postText = `${title}\n\nHuman-authored: ${bundle.total_keystroke_count.toLocaleString()} keystrokes, ${bundle.commitments.length} commitments.\n\nVerify: ${verifierUrl}`;

  // Find verifier URL position in text for link facet
  const urlStart = postText.indexOf(verifierUrl);
  const encoder = new TextEncoder();
  const byteStart = encoder.encode(postText.slice(0, urlStart)).length;
  const byteEnd = byteStart + encoder.encode(verifierUrl).length;

  const record = {
    $type: "app.bsky.feed.post",
    text: postText,
    createdAt: new Date().toISOString(),
    facets: [
      {
        index: { byteStart, byteEnd },
        features: [
          {
            $type: "app.bsky.richtext.facet#link",
            uri: verifierUrl,
          },
        ],
      },
    ],
  };

  const response = await agent.com.atproto.repo.createRecord({
    repo: agent.did,
    collection: "app.bsky.feed.post",
    record,
  });

  return { uri: response.data.uri, cid: response.data.cid };
}
