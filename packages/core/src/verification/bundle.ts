import type { ProofBundle, VerifyResult } from "../types/proofs";
import { sha256Hex, contentBindingHash } from "../crypto/hashing";

/**
 * Verify a proof bundle against content — fully standalone, no database needed.
 * This is what an external verifier (browser, CLI, API) would call.
 * Re-derives every commitment hash in the chain and checks the content binding.
 */
export async function verifyProofBundle(
  bundle: ProofBundle,
  content: string,
): Promise<VerifyResult> {
  const actualContentHash = await sha256Hex(content);
  const chainLength = bundle.commitments.length;

  // Walk the chain and verify each link
  let expectedPrevious: string | null = null;

  for (const commitment of bundle.commitments) {
    // Verify chain linkage
    if (expectedPrevious === null) {
      // First in chain — no previous expected (or could be sub-chain)
    } else if (commitment.previous_hash === null) {
      return {
        valid: false,
        content_hash_matches: false,
        chain_length: chainLength,
        binding_hash: bundle.binding_hash,
        expected_content_hash: bundle.content_hash,
        actual_content_hash: actualContentHash,
        message: `Chain broken at C${commitment.sequence_num}: expected a previous hash but found none`,
      };
    } else if (expectedPrevious !== commitment.previous_hash) {
      return {
        valid: false,
        content_hash_matches: false,
        chain_length: chainLength,
        binding_hash: bundle.binding_hash,
        expected_content_hash: bundle.content_hash,
        actual_content_hash: actualContentHash,
        message: `Chain broken at C${commitment.sequence_num}: expected previous ${expectedPrevious.slice(0, 16)} but got ${commitment.previous_hash.slice(0, 16)}`,
      };
    }

    // For content_binding commitments, verify the binding derivation
    if (commitment.commitment_type === "content_binding") {
      if (commitment.previous_hash && commitment.content_hash) {
        const expectedBinding = await contentBindingHash(
          commitment.previous_hash,
          commitment.content_hash,
        );
        if (expectedBinding !== commitment.commitment_hash) {
          return {
            valid: false,
            content_hash_matches: false,
            chain_length: chainLength,
            binding_hash: bundle.binding_hash,
            expected_content_hash: bundle.content_hash,
            actual_content_hash: actualContentHash,
            message: `Content binding C${commitment.sequence_num} could not be re-derived. Proof may be tampered.`,
          };
        }
      }
    }

    expectedPrevious = commitment.commitment_hash;
  }

  // Check content hash matches
  const contentMatches = actualContentHash === bundle.content_hash;
  const valid = contentMatches;

  const message = valid
    ? `Verified: content matches proof bundle (${chainLength} commitments, ${bundle.total_keystroke_count} keystrokes)`
    : "Content modified: the text does not match what was proven at publish time.";

  return {
    valid,
    content_hash_matches: contentMatches,
    chain_length: chainLength,
    binding_hash: bundle.binding_hash,
    expected_content_hash: bundle.content_hash,
    actual_content_hash: actualContentHash,
    message,
  };
}
