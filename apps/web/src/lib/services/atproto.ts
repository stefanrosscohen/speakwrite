import { BrowserOAuthClient } from "@atproto/oauth-client-browser";
import { Agent } from "@atproto/api";
import type { ProofBundle } from "@speakwrite/core";

const IS_DEV = import.meta.env.DEV;

const oauthClient = new BrowserOAuthClient({
  handleResolver: "https://bsky.social",
  clientMetadata: IS_DEV
    ? undefined
    : {
        client_id: "https://www.speakwrite.io/app/client-metadata.json",
        client_name: "Speakwrite",
        client_uri: "https://www.speakwrite.io",
        redirect_uris: ["https://www.speakwrite.io/app/"],
        scope: "atproto transition:generic",
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

    // Resolve handle from DID using describeRepo (works on any PDS)
    try {
      const desc = await agent.com.atproto.repo.describeRepo({
        repo: session.did,
      });
      return {
        did: session.did,
        handle: desc.data.handle,
      };
    } catch {
      // Fallback: use DID as display name
      return {
        did: session.did,
        handle: session.did,
      };
    }
  }

  return null;
}

/**
 * Initiates OAuth sign-in. Redirects the browser to the user's PDS auth page.
 * This promise never resolves on success — the page navigates away.
 *
 * Tries with transition:generic (write access) first. If the PDS rejects that
 * scope (older / self-hosted PDSes), retries with base atproto scope only.
 * Without transition:generic, publishing will not work — only reading.
 */
export async function signIn(handle: string): Promise<void> {
  const state = crypto.randomUUID();
  try {
    await oauthClient.signIn(handle, {
      state,
      scope: "atproto transition:generic",
    });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    if (
      message.includes("invalid_scope") ||
      message.includes("not declared") ||
      message.includes("Unsupported scope") ||
      message.includes("transition:generic")
    ) {
      // PDS doesn't support transition:generic — fall back to base scope.
      // Publishing will fail but at least auth works.
      console.warn(
        "PDS does not support transition:generic, falling back to atproto scope (read-only)",
      );
      await oauthClient.signIn(handle, {
        state,
        scope: "atproto",
      });
    } else {
      throw err;
    }
  }
}

/**
 * Clears the current agent, revokes OAuth session, and cleans up storage.
 * Reloads the page to ensure a clean state.
 */
export async function logout(): Promise<void> {
  // Revoke the OAuth session (clears tokens from IndexedDB)
  if (agent?.did) {
    try {
      await oauthClient.revoke(agent.did);
    } catch {
      // Best-effort revocation
    }
  }
  agent = null;

  // Clean up legacy app-password session data from Dexie
  try {
    const { db } = await import("../db");
    await db.settings.delete("atproto_session");
  } catch {
    // ignore
  }

  // Reload to get a clean OAuthClient state
  window.location.reload();
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

/**
 * Publish the proof bundle as a Bluesky post.
 * The post text contains the content, keystroke count, and a verifier link.
 * The proof bundle is stored as a self-label for now (v1).
 */
export async function publishProofPost(
  bundle: ProofBundle,
  postText: string,
): Promise<{ uri: string; cid: string }> {
  if (!agent?.did) throw new Error("Not logged in to AT Protocol");

  // Truncate post text to fit Bluesky's 300 grapheme limit
  // Leave room for the proof footer
  const footer = `\n\n\u2705 ${bundle.total_keystroke_count.toLocaleString()} keystrokes \u00b7 ${bundle.commitments.length} commitments`;
  const maxContentLen = 300 - footer.length;
  const trimmedContent =
    postText.length > maxContentLen
      ? postText.slice(0, maxContentLen - 1) + "\u2026"
      : postText;

  const fullText = trimmedContent + footer;

  const record = {
    $type: "app.bsky.feed.post",
    text: fullText,
    createdAt: new Date().toISOString(),
  };

  const response = await agent.com.atproto.repo.createRecord({
    repo: agent.did,
    collection: "app.bsky.feed.post",
    record,
  });

  return { uri: response.data.uri, cid: response.data.cid };
}
