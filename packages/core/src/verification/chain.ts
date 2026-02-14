import type { ProofBundleCommitment } from "../types/proofs";
import { contentBindingHash } from "../crypto/hashing";

export interface ChainIntegrityResult {
  valid: boolean;
  brokenAt: number | null;
  message: string;
}

/**
 * Verify chain integrity only (no content hash check).
 * Walks the commitment chain and verifies each link.
 */
export async function verifyChainIntegrity(
  commitments: ProofBundleCommitment[],
): Promise<ChainIntegrityResult> {
  if (commitments.length === 0) {
    return { valid: false, brokenAt: null, message: "Empty chain" };
  }

  let expectedPrevious: string | null = null;

  for (const commitment of commitments) {
    if (expectedPrevious !== null) {
      if (commitment.previous_hash === null) {
        return {
          valid: false,
          brokenAt: commitment.sequence_num,
          message: `C${commitment.sequence_num}: expected previous hash but found none`,
        };
      }
      if (expectedPrevious !== commitment.previous_hash) {
        return {
          valid: false,
          brokenAt: commitment.sequence_num,
          message: `C${commitment.sequence_num}: previous hash mismatch`,
        };
      }
    }

    // Verify content binding re-derivation
    if (commitment.commitment_type === "content_binding") {
      if (commitment.previous_hash && commitment.content_hash) {
        const expected = await contentBindingHash(
          commitment.previous_hash,
          commitment.content_hash,
        );
        if (expected !== commitment.commitment_hash) {
          return {
            valid: false,
            brokenAt: commitment.sequence_num,
            message: `C${commitment.sequence_num}: content binding could not be re-derived`,
          };
        }
      }
    }

    expectedPrevious = commitment.commitment_hash;
  }

  return {
    valid: true,
    brokenAt: null,
    message: `Chain valid: ${commitments.length} commitments`,
  };
}
