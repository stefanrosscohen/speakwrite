/**
 * Verification logic for the reader.
 * Wraps @speakwrite/core's verifyProofBundle with PDS proof record lookup.
 */

import { verifyProofBundle } from "@speakwrite/core";
import type { ProofBundle, VerifyResult } from "@speakwrite/core";
import { fetchProofRecords } from "./bluesky-api";
import { sha256Hex } from "@speakwrite/core";

export type VerificationStatus =
  | { type: "footer_only"; keystrokes: number; commitments: number }
  | { type: "verifying" }
  | { type: "verified"; result: VerifyResult; bundle: ProofBundle }
  | { type: "failed"; error: string };

/**
 * Attempt to find and verify a proof bundle for a post.
 *
 * 1. Fetch io.speakwrite.proof records from the author's PDS
 * 2. Match by content hash (SHA-256 of the post's content text)
 * 3. If found, run verifyProofBundle() from @speakwrite/core
 */
export async function attemptVerification(
  did: string,
  contentText: string,
): Promise<VerificationStatus | null> {
  try {
    // Compute the content hash to match against proof records
    const contentHash = await sha256Hex(contentText);

    // Fetch proof records from the author's PDS
    const records = await fetchProofRecords(did);
    if (!records || records.length === 0) return null;

    // Find a matching proof record by content hash
    for (const record of records) {
      const val = record.value as Record<string, unknown>;
      if (val.contentHash === contentHash && typeof val.proofBundle === "string") {
        try {
          const bundle: ProofBundle = JSON.parse(val.proofBundle as string);
          const result = await verifyProofBundle(bundle, contentText);
          if (result.valid) {
            return { type: "verified", result, bundle };
          } else {
            return { type: "failed", error: result.message };
          }
        } catch (e) {
          return { type: "failed", error: String(e) };
        }
      }
    }

    // No matching proof record found
    return null;
  } catch {
    return null;
  }
}
