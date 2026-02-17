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

/** Build a valid v2 bundle with openable commitments and document hashes. */
async function buildValidBundle(content: string): Promise<ProofBundle> {
  const contentHash = await sha256Hex(content);

  // Simulate document growing over time
  const partialContent0 = content.slice(0, Math.floor(content.length * 0.5));
  const docHash0 = await sha256Hex(partialContent0);

  const docHash1 = contentHash; // Final checkpoint has the full content

  const features0 = JSON.stringify({ typing_speed_cpm: 300, keystroke_count: 50 });
  const features1 = JSON.stringify({ typing_speed_cpm: 320, keystroke_count: 100 });

  const commitments: ProofBundleCommitment[] = [];

  // C0: first behavioral commitment
  const nonce0 = randomNonce();
  const data0 = new TextEncoder().encode(features0);
  const hash0 = await commitmentHash(null, nonce0, data0, docHash0);
  commitments.push({
    sequence_num: 0,
    commitment_hash: hash0,
    previous_hash: null,
    nonce: hexEncode(nonce0),
    timestamp_ms: 1000,
    commitment_type: "behavioral",
    content_hash: null,
    features_json: features0,
    document_hash: docHash0,
    document_length: partialContent0.length,
    keystroke_count: 50,
  });

  // C1: second behavioral commitment
  const nonce1 = randomNonce();
  const data1 = new TextEncoder().encode(features1);
  const hash1 = await commitmentHash(hash0, nonce1, data1, docHash1);
  commitments.push({
    sequence_num: 1,
    commitment_hash: hash1,
    previous_hash: hash0,
    nonce: hexEncode(nonce1),
    timestamp_ms: 2000,
    commitment_type: "behavioral",
    content_hash: null,
    features_json: features1,
    document_hash: docHash1,
    document_length: content.length,
    keystroke_count: 100,
  });

  // C2: content binding
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
    version: "2.0.0",
    document_id: "test-doc",
    content_hash: contentHash,
    commitments,
    binding_hash: bindingHash,
    total_keystroke_count: 100,
    created_at: new Date().toISOString(),
  };
}

/** Build a valid v1 bundle (no features_json, no document_hash) for backward compat. */
async function buildValidV1Bundle(content: string): Promise<ProofBundle> {
  const contentHash = await sha256Hex(content);
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
  // --- Basic verification (v2 bundles) ---

  it("verifies a valid v2 bundle with openable commitments", async () => {
    const content = "Hello, world!";
    const bundle = await buildValidBundle(content);
    const result = await verifyProofBundle(bundle, content);

    expect(result.valid).toBe(true);
    expect(result.content_hash_matches).toBe(true);
    expect(result.chain_length).toBe(3);
    expect(result.message).toContain("Verified");
    expect(result.message).toContain("3 commitments");
    expect(result.consistency_warnings).toEqual([]);
  });

  it("verifies a valid v1 bundle (backward compat, no features_json)", async () => {
    const content = "Hello, world!";
    const bundle = await buildValidV1Bundle(content);
    const result = await verifyProofBundle(bundle, content);

    expect(result.valid).toBe(true);
    expect(result.content_hash_matches).toBe(true);
    expect(result.chain_length).toBe(3);
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
    bundle.commitments[1].previous_hash = "0000000000000000";

    const result = await verifyProofBundle(bundle, content);
    expect(result.valid).toBe(false);
    expect(result.message).toContain("Chain broken");
  });

  it("fails if content binding is tampered", async () => {
    const content = "Test content";
    const bundle = await buildValidBundle(content);
    bundle.commitments[2].commitment_hash = "deadbeefdeadbeef";

    const result = await verifyProofBundle(bundle, content);
    expect(result.valid).toBe(false);
    expect(result.message).toContain("could not be re-derived");
  });

  it("fails if previous hash is missing when expected", async () => {
    const content = "Test";
    const bundle = await buildValidBundle(content);
    bundle.commitments[1].previous_hash = null;

    const result = await verifyProofBundle(bundle, content);
    expect(result.valid).toBe(false);
    expect(result.message).toContain("expected a previous hash");
  });

  // --- Fix 1: Openable commitment re-derivation ---

  it("fails if features_json is tampered (re-derivation fails)", async () => {
    const content = "Test content for re-derivation";
    const bundle = await buildValidBundle(content);

    // Tamper with features_json on the first commitment
    bundle.commitments[0].features_json = '{"typing_speed_cpm":9999,"keystroke_count":1}';

    const result = await verifyProofBundle(bundle, content);
    expect(result.valid).toBe(false);
    expect(result.message).toContain("Behavioral commitment C0 could not be re-derived");
  });

  it("fails if nonce is tampered on openable commitment", async () => {
    const content = "Test content for nonce tampering";
    const bundle = await buildValidBundle(content);

    // Change the nonce — re-derivation should fail
    bundle.commitments[0].nonce = hexEncode(randomNonce());

    const result = await verifyProofBundle(bundle, content);
    expect(result.valid).toBe(false);
    expect(result.message).toContain("could not be re-derived");
  });

  // --- Fix 2: Document hash binding ---

  it("fails if last document_hash doesn't match content_hash", async () => {
    const content = "Test content for document hash";
    const bundle = await buildValidBundle(content);

    // Tamper with the last behavioral commitment's document_hash
    // (We need to also re-derive the commitment hash to not trip re-derivation first)
    // Instead, just set document_hash to a wrong value without features_json to skip re-derivation
    const wrongDocHash = await sha256Hex("wrong content");
    // Remove features_json so re-derivation is skipped, then set wrong document_hash
    delete (bundle.commitments[1] as any).features_json;
    bundle.commitments[1].document_hash = wrongDocHash;
    // Also need to make this not a v2 bundle so document_hash presence isn't required
    bundle.version = "1.0.0";

    const result = await verifyProofBundle(bundle, content);
    expect(result.valid).toBe(false);
    expect(result.message).toContain("does not match bundle content_hash");
  });

  it("fails if v2 behavioral commitment is missing document_hash", async () => {
    const content = "Test";
    const bundle = await buildValidBundle(content);

    // Remove document_hash from first commitment but keep features_json
    // First remove features_json to avoid re-derivation failure
    delete (bundle.commitments[0] as any).features_json;
    delete (bundle.commitments[0] as any).document_hash;

    const result = await verifyProofBundle(bundle, content);
    expect(result.valid).toBe(false);
    expect(result.message).toContain("missing document_hash");
  });

  // --- Fix 4: Consistency checks ---

  it("warns about implausibly low keystroke count", async () => {
    const content = "A".repeat(200); // 200 chars
    const bundle = await buildValidBundle(content);
    bundle.total_keystroke_count = 10; // Way too few

    const result = await verifyProofBundle(bundle, content);
    // Still valid (warnings are non-fatal) but should have warning
    expect(result.valid).toBe(true);
    expect(result.consistency_warnings).toBeDefined();
    expect(result.consistency_warnings!.some(w => w.includes("implausibly low"))).toBe(true);
  });

  it("warns about non-monotonic timestamps", async () => {
    const content = "Test";
    const bundle = await buildValidBundle(content);
    // Make timestamp go backwards
    bundle.commitments[1].timestamp_ms = 500; // before C0's 1000

    const result = await verifyProofBundle(bundle, content);
    expect(result.valid).toBe(true); // non-fatal
    expect(result.consistency_warnings!.some(w => w.includes("Timestamp not increasing"))).toBe(true);
  });

  it("warns about non-monotonic keystroke counts", async () => {
    const content = "Test content";
    const bundle = await buildValidBundle(content);
    // Make keystroke_count decrease (need to rebuild to avoid re-derivation issues)
    // Just tamper without features_json
    bundle.version = "1.0.0";
    delete (bundle.commitments[0] as any).features_json;
    delete (bundle.commitments[1] as any).features_json;
    bundle.commitments[0].keystroke_count = 100;
    bundle.commitments[1].keystroke_count = 50; // decrease

    const result = await verifyProofBundle(bundle, content);
    expect(result.valid).toBe(true);
    expect(result.consistency_warnings!.some(w => w.includes("Keystroke count decreased"))).toBe(true);
  });

  it("warns about inhuman typing speed in features_json", async () => {
    const content = "Test content for speed check";
    // Build a bundle with inhuman speed
    const contentHash = await sha256Hex(content);
    const docHash = contentHash;
    const features = JSON.stringify({ typing_speed_cpm: 5000 }); // way too fast
    const nonce0 = randomNonce();
    const data0 = new TextEncoder().encode(features);
    const hash0 = await commitmentHash(null, nonce0, data0, docHash);

    const bindingHash = await contentBindingHash(hash0, contentHash);

    const bundle: ProofBundle = {
      version: "2.0.0",
      document_id: "test",
      content_hash: contentHash,
      commitments: [
        {
          sequence_num: 0,
          commitment_hash: hash0,
          previous_hash: null,
          nonce: hexEncode(nonce0),
          timestamp_ms: 1000,
          commitment_type: "behavioral",
          content_hash: null,
          features_json: features,
          document_hash: docHash,
          document_length: content.length,
          keystroke_count: 100,
        },
        {
          sequence_num: 1,
          commitment_hash: bindingHash,
          previous_hash: hash0,
          nonce: "",
          timestamp_ms: 2000,
          commitment_type: "content_binding",
          content_hash: contentHash,
        },
      ],
      binding_hash: bindingHash,
      total_keystroke_count: 100,
      created_at: new Date().toISOString(),
    };

    const result = await verifyProofBundle(bundle, content);
    expect(result.valid).toBe(true);
    expect(result.consistency_warnings!.some(w => w.includes("outside human range"))).toBe(true);
  });

  // --- Fix 3: Attestation fields present in result ---

  it("returns attestation fields when no device_attestation is present", async () => {
    const content = "Test";
    const bundle = await buildValidBundle(content);
    const result = await verifyProofBundle(bundle, content);

    expect(result.signatures_valid).toBeUndefined();
    expect(result.attestation_level).toBeUndefined();
    expect(result.signature_count).toBe(0);
  });

  it("reports clean consistency_warnings for a well-formed bundle", async () => {
    const content = "The quick brown fox jumps over the lazy dog.";
    const bundle = await buildValidBundle(content);
    const result = await verifyProofBundle(bundle, content);

    expect(result.valid).toBe(true);
    expect(result.consistency_warnings).toEqual([]);
  });
});
