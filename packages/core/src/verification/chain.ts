import type { ProofBundleCommitment } from "../types/proofs";
import { contentBindingHash, commitmentHash, hexDecode } from "../crypto/hashing";

export interface ChainIntegrityResult {
  valid: boolean;
  brokenAt: number | null;
  message: string;
}

/**
 * Verify chain integrity only (no content hash check).
 * Walks the commitment chain and verifies each link.
 * v2: Also re-derives behavioral commitment hashes when features_json is present.
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

    // Re-derive behavioral commitment hash if features_json is present (openable)
    if (commitment.commitment_type === "behavioral" && commitment.features_json !== undefined) {
      const nonceBytes = hexDecode(commitment.nonce);
      const featuresBytes = new TextEncoder().encode(commitment.features_json);
      const expected = await commitmentHash(
        commitment.previous_hash,
        nonceBytes,
        featuresBytes,
        commitment.document_hash,
      );
      if (expected !== commitment.commitment_hash) {
        return {
          valid: false,
          brokenAt: commitment.sequence_num,
          message: `C${commitment.sequence_num}: behavioral commitment could not be re-derived`,
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
