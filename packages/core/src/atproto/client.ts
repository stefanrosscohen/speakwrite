/**
 * AT Protocol client for publishing Speakwrite proofs.
 * Requires @atproto/api as a peer dependency.
 */

import type { ProofBundle } from "../types/proofs";
import type { ATProtoPostResult } from "../types/atproto";
import { PROOF_COLLECTION } from "./lexicon";

interface BskyAgent {
  login(opts: { identifier: string; password: string }): Promise<void>;
  post(opts: {
    text: string;
    facets?: unknown[];
    createdAt?: string;
  }): Promise<{ uri: string; cid: string }>;
  session?: { did: string };
  com: {
    atproto: {
      repo: {
        createRecord(opts: {
          repo: string;
          collection: string;
          record: Record<string, unknown>;
        }): Promise<{ data: { uri: string; cid: string } }>;
      };
    };
  };
}

interface RichText {
  text: string;
  facets?: unknown[];
  detectFacets(agent: BskyAgent): Promise<void>;
}

/** Create a proof record on the user's PDS using the custom lexicon. */
export async function createProofRecord(
  agent: BskyAgent,
  bundle: ProofBundle,
  verifierUrl: string,
): Promise<ATProtoPostResult> {
  if (!agent.session?.did) {
    throw new Error("Not logged in");
  }

  const response = await agent.com.atproto.repo.createRecord({
    repo: agent.session.did,
    collection: PROOF_COLLECTION,
    record: {
      $type: PROOF_COLLECTION,
      contentHash: bundle.content_hash,
      bindingHash: bundle.binding_hash,
      chainLength: bundle.commitments.length,
      totalKeystrokes: bundle.total_keystroke_count,
      proofBundle: JSON.stringify(bundle),
      verifierUrl,
      createdAt: new Date().toISOString(),
    },
  });

  return { uri: response.data.uri, cid: response.data.cid };
}

/** Create a regular Bluesky post announcing a proof. */
export async function createProofPost(
  agent: BskyAgent,
  opts: {
    title: string;
    bundle: ProofBundle;
    verifierUrl: string;
    RichText: new (opts: { text: string }) => RichText;
  },
): Promise<ATProtoPostResult> {
  const { title, bundle, verifierUrl, RichText } = opts;

  const text = [
    title,
    "",
    `Written with Speakwrite`,
    `${bundle.commitments.length} commitments | ${bundle.total_keystroke_count.toLocaleString()} keystrokes`,
    `Content: ${bundle.content_hash.slice(0, 16)}...`,
    `Verify: ${verifierUrl}`,
  ].join("\n");

  const rt = new RichText({ text });
  await rt.detectFacets(agent);

  const response = await agent.post({
    text: rt.text,
    facets: rt.facets,
    createdAt: new Date().toISOString(),
  });

  return { uri: response.uri, cid: response.cid };
}
