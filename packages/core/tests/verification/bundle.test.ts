import { describe, it, expect } from "vitest";
import { verifyProofBundle } from "../../src/verification/bundle";
import {
  sha256Hex,
  commitmentHash,
  contentBindingHash,
  hexEncode,
} from "../../src/crypto/hashing";
import { randomNonce } from "../../src/crypto/nonce";
import type { ProofBundle, ProofBundleCommitment } from "../../src/types/proofs";

async function buildValidBundle(content: string): Promise<ProofBundle> {
  const contentHash = await sha256Hex(content);

  // Build a 3-commitment chain
  const commitments: ProofBundleCommitment[] = [];

  const nonce0 = randomNonce();
  const data0 = new TextEncoder().encode('{"tier1":{},"tier2":{}}');
  const hash0 = await commitmentHash(null, nonce0, data0);
  commitments.push({
    sequence_num: 0,
    commitment_hash: hash0,
    previous_hash: null,
    nonce: hexEncode(nonce0),
    timestamp_ms: 1000,
    commitment_type: "behavioral",
    content_hash: null,
  });

  const nonce1 = randomNonce();
  const data1 = new TextEncoder().encode('{"tier1":{},"tier2":{}}');
  const hash1 = await commitmentHash(hash0, nonce1, data1);
  commitments.push({
    sequence_num: 1,
    commitment_hash: hash1,
    previous_hash: hash0,
    nonce: hexEncode(nonce1),
    timestamp_ms: 2000,
    commitment_type: "behavioral",
    content_hash: null,
  });

  // Content binding
  const bindingHash = await contentBindingHash(hash1, contentHash);
  commitments.push({
    sequence_num: 2,
    commitment_hash: bindingHash,
    previous_hash: hash1,
    nonce: "",
    timestamp_ms: 3000,
    commitment_type: "content_binding",
    content_hash: contentHash,
  });

  return {
    version: "1.0.0",
    document_id: "test-doc",
    content_hash: contentHash,
    commitments,
    binding_hash: bindingHash,
    total_keystroke_count: 500,
    created_at: new Date().toISOString(),
  };
}

describe("verifyProofBundle", () => {
  it("verifies a valid bundle", async () => {
    const content = "Hello, world!";
    const bundle = await buildValidBundle(content);
    const result = await verifyProofBundle(bundle, content);

    expect(result.valid).toBe(true);
    expect(result.content_hash_matches).toBe(true);
    expect(result.chain_length).toBe(3);
    expect(result.message).toContain("Verified");
    expect(result.message).toContain("3 commitments");
    expect(result.message).toContain("500 keystrokes");
  });

  it("fails if content is modified", async () => {
    const content = "Hello, world!";
    const bundle = await buildValidBundle(content);
    const result = await verifyProofBundle(bundle, "Hello, MODIFIED!");

    expect(result.valid).toBe(false);
    expect(result.content_hash_matches).toBe(false);
    expect(result.message).toContain("Content modified");
  });

  it("fails if chain link is broken", async () => {
    const content = "Test content";
    const bundle = await buildValidBundle(content);

    // Break chain by modifying a previous_hash
    bundle.commitments[1].previous_hash = "0000000000000000";

    const result = await verifyProofBundle(bundle, content);
    expect(result.valid).toBe(false);
    expect(result.message).toContain("Chain broken");
  });

  it("fails if content binding is tampered", async () => {
    const content = "Test content";
    const bundle = await buildValidBundle(content);

    // Tamper with the content binding commitment hash
    bundle.commitments[2].commitment_hash = "deadbeefdeadbeef";

    const result = await verifyProofBundle(bundle, content);
    expect(result.valid).toBe(false);
    expect(result.message).toContain("could not be re-derived");
  });

  it("fails if previous hash is missing when expected", async () => {
    const content = "Test";
    const bundle = await buildValidBundle(content);

    // Remove previous_hash from second commitment
    bundle.commitments[1].previous_hash = null;

    const result = await verifyProofBundle(bundle, content);
    expect(result.valid).toBe(false);
    expect(result.message).toContain("expected a previous hash");
  });
});
