import type { ProofBundle, ProofBundleCommitment, VerifyResult } from "../types/proofs";
import { sha256Hex, commitmentHash, contentBindingHash, hexDecode, hexEncode } from "../crypto/hashing";

/**
 * Verify a proof bundle against content — fully standalone, no database needed.
 * This is what an external verifier (browser, CLI, API) would call.
 *
 * v2: Re-derives every behavioral commitment hash (openable commitments),
 * verifies content binding to keystroke chain, verifies device signatures,
 * and runs plausibility checks.
 */
export async function verifyProofBundle(
  bundle: ProofBundle,
  content: string,
): Promise<VerifyResult> {
  const actualContentHash = await sha256Hex(content);
  const chainLength = bundle.commitments.length;
  const consistencyWarnings: string[] = [];

  const fail = (message: string): VerifyResult => ({
    valid: false,
    content_hash_matches: false,
    chain_length: chainLength,
    binding_hash: bundle.binding_hash,
    expected_content_hash: bundle.content_hash,
    actual_content_hash: actualContentHash,
    message,
    consistency_warnings: consistencyWarnings,
  });

  // --- Chain walk: verify linkage + re-derive commitment hashes ---
  let expectedPrevious: string | null = null;
  const behavioralCommitments: ProofBundleCommitment[] = [];

  for (const commitment of bundle.commitments) {
    // Verify chain linkage
    if (expectedPrevious !== null) {
      if (commitment.previous_hash === null) {
        return fail(
          `Chain broken at C${commitment.sequence_num}: expected a previous hash but found none`,
        );
      }
      if (expectedPrevious !== commitment.previous_hash) {
        return fail(
          `Chain broken at C${commitment.sequence_num}: expected previous ${expectedPrevious.slice(0, 16)} but got ${commitment.previous_hash.slice(0, 16)}`,
        );
      }
    }

    if (commitment.commitment_type === "behavioral") {
      behavioralCommitments.push(commitment);

      // Fix 1: Re-derive behavioral commitment hash if features_json is present (openable)
      if (commitment.features_json !== undefined) {
        const nonceBytes = hexDecode(commitment.nonce);
        const featuresBytes = new TextEncoder().encode(commitment.features_json);
        const expected = await commitmentHash(
          commitment.previous_hash,
          nonceBytes,
          featuresBytes,
          commitment.document_hash,
        );
        if (expected !== commitment.commitment_hash) {
          return fail(
            `Behavioral commitment C${commitment.sequence_num} could not be re-derived. Proof may be tampered.`,
          );
        }
      }

      // Fix 2: Verify document_hash is present on v2 behavioral commitments
      if (bundle.version === "2.0.0" && !commitment.document_hash) {
        return fail(
          `Behavioral commitment C${commitment.sequence_num} missing document_hash (required in v2)`,
        );
      }
    }

    // For content_binding commitments, verify the binding derivation
    if (commitment.commitment_type === "content_binding") {
      if (commitment.previous_hash && commitment.content_hash) {
        const expectedBinding = await contentBindingHash(
          commitment.previous_hash,
          commitment.content_hash,
        );
        if (expectedBinding !== commitment.commitment_hash) {
          return fail(
            `Content binding C${commitment.sequence_num} could not be re-derived. Proof may be tampered.`,
          );
        }
      }
    }

    expectedPrevious = commitment.commitment_hash;
  }

  // --- Fix 2: Verify last behavioral commitment's document_hash matches content_hash ---
  if (behavioralCommitments.length > 0) {
    const lastBehavioral = behavioralCommitments[behavioralCommitments.length - 1];
    if (lastBehavioral.document_hash && lastBehavioral.document_hash !== bundle.content_hash) {
      return fail(
        `Last behavioral commitment's document_hash (${lastBehavioral.document_hash.slice(0, 16)}) does not match bundle content_hash (${bundle.content_hash.slice(0, 16)})`,
      );
    }
  }

  // Check content hash matches
  const contentMatches = actualContentHash === bundle.content_hash;
  if (!contentMatches) {
    return {
      valid: false,
      content_hash_matches: false,
      chain_length: chainLength,
      binding_hash: bundle.binding_hash,
      expected_content_hash: bundle.content_hash,
      actual_content_hash: actualContentHash,
      message: "Content modified: the text does not match what was proven at publish time.",
      consistency_warnings: consistencyWarnings,
    };
  }

  // --- Fix 3: Device attestation signature verification ---
  let signaturesValid: boolean | undefined;
  let attestationLevel: string | null | undefined;
  let signatureCount = 0;

  if (bundle.device_attestation) {
    const att = bundle.device_attestation;
    attestationLevel = att.attestation_level;

    try {
      const pubKey = await importP256PublicKey(att.device_public_key);
      let allSigsValid = true;

      // Verify checkpoint signatures
      for (const cs of att.checkpoint_signatures) {
        const message = `speakwrite:checkpoint:${cs.sequence_num}|${cs.commitment_hash}`;
        const valid = await verifyECDSA(pubKey, cs.signature, message);
        if (!valid) {
          allSigsValid = false;
          consistencyWarnings.push(
            `Checkpoint signature for C${cs.sequence_num} failed verification`,
          );
        }
        signatureCount++;
      }

      // Verify session start signature
      if (att.session_binding?.session_start_signature && att.session_binding.session_start_timestamp) {
        const message = `speakwrite:session:${att.session_binding.session_id}|${att.session_binding.session_start_timestamp}`;
        const valid = await verifyECDSA(
          pubKey,
          att.session_binding.session_start_signature,
          message,
        );
        if (!valid) {
          allSigsValid = false;
          consistencyWarnings.push("Session start signature failed verification");
        }
        signatureCount++;
      }

      // Verify final signature
      if (att.final_signature) {
        const message = `speakwrite:binding:${bundle.content_hash}|${bundle.binding_hash}`;
        const valid = await verifyECDSA(pubKey, att.final_signature, message);
        if (!valid) {
          allSigsValid = false;
          consistencyWarnings.push("Final signature failed verification");
        }
        signatureCount++;
      }

      signaturesValid = allSigsValid;

      // Key provenance warnings
      if (att.attestation_certificate) {
        consistencyWarnings.push(
          "App Attest certificate present but not verified (CBOR chain verification not implemented). Signatures are internally consistent but key provenance is unverified.",
        );
      } else {
        consistencyWarnings.push(
          "No attestation certificate. Signatures verified against self-asserted public key only.",
        );
      }
    } catch (e) {
      signaturesValid = false;
      consistencyWarnings.push(
        `Signature verification error: ${e instanceof Error ? e.message : String(e)}`,
      );
    }
  }

  // --- Fix 4: Keystroke-content consistency checks ---
  runConsistencyChecks(bundle, behavioralCommitments, consistencyWarnings);

  const message = `Verified: content matches proof bundle (${chainLength} commitments, ${bundle.total_keystroke_count} keystrokes)`;

  return {
    valid: true,
    content_hash_matches: true,
    chain_length: chainLength,
    binding_hash: bundle.binding_hash,
    expected_content_hash: bundle.content_hash,
    actual_content_hash: actualContentHash,
    message,
    signatures_valid: signaturesValid,
    key_attested: bundle.device_attestation ? false : undefined,
    attestation_level: attestationLevel,
    signature_count: signatureCount,
    consistency_warnings: consistencyWarnings,
  };
}

// --- Fix 3 helpers: ECDSA P-256 signature verification ---

async function importP256PublicKey(base64Key: string): Promise<CryptoKey> {
  let raw = base64ToBytes(base64Key);
  // CryptoKit rawRepresentation is 64 bytes (x||y).
  // Web Crypto "raw" import expects 65 bytes (0x04||x||y).
  if (raw.length === 64) {
    const uncompressed = new Uint8Array(65);
    uncompressed[0] = 0x04;
    uncompressed.set(raw, 1);
    raw = uncompressed;
  }
  return crypto.subtle.importKey(
    "raw",
    raw,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["verify"],
  );
}

async function verifyECDSA(
  key: CryptoKey,
  signatureBase64: string,
  message: string,
): Promise<boolean> {
  const signature = base64ToBytes(signatureBase64);
  const data = new TextEncoder().encode(message);
  // Copy into fresh ArrayBuffers for Web Crypto
  const sigBuf = new ArrayBuffer(signature.length);
  new Uint8Array(sigBuf).set(signature);
  const dataBuf = new ArrayBuffer(data.length);
  new Uint8Array(dataBuf).set(data);
  return crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    sigBuf,
    dataBuf,
  );
}

function base64ToBytes(base64: string): Uint8Array {
  // Handle both standard and URL-safe base64
  const normalized = base64.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

// --- Fix 4: Consistency checks ---

function runConsistencyChecks(
  bundle: ProofBundle,
  behavioralCommitments: ProofBundleCommitment[],
  warnings: string[],
): void {
  // Check keystroke count vs content length plausibility
  if (bundle.total_keystroke_count > 0) {
    const contentLength = bundle.content_hash.length > 0
      ? estimateContentLength(behavioralCommitments, bundle)
      : 0;
    if (contentLength > 0 && bundle.total_keystroke_count < contentLength * 0.5) {
      warnings.push(
        `Keystroke count (${bundle.total_keystroke_count}) is implausibly low for content length (${contentLength}): expected at least ${Math.floor(contentLength * 0.5)}`,
      );
    }
  }

  // Check monotonicity of keystroke_count across commitments
  let prevKeystrokeCount = -1;
  for (const c of behavioralCommitments) {
    if (c.keystroke_count !== undefined) {
      if (c.keystroke_count < prevKeystrokeCount) {
        warnings.push(
          `Keystroke count decreased at C${c.sequence_num}: ${c.keystroke_count} < ${prevKeystrokeCount}`,
        );
      }
      prevKeystrokeCount = c.keystroke_count;
    }
  }

  // Check monotonicity of document_length across commitments (with tolerance for deletions)
  let prevDocLength = -1;
  let docLengthDecreaseCount = 0;
  for (const c of behavioralCommitments) {
    if (c.document_length !== undefined) {
      if (c.document_length < prevDocLength) {
        docLengthDecreaseCount++;
      }
      prevDocLength = c.document_length;
    }
  }
  if (docLengthDecreaseCount > behavioralCommitments.length * 0.5) {
    warnings.push(
      `Document length decreased in ${docLengthDecreaseCount}/${behavioralCommitments.length} commitments — unusual pattern`,
    );
  }

  // Check timestamp monotonicity
  let prevTimestamp = -1;
  for (const c of bundle.commitments) {
    if (c.timestamp_ms <= prevTimestamp) {
      warnings.push(
        `Timestamp not increasing at C${c.sequence_num}: ${c.timestamp_ms} <= ${prevTimestamp}`,
      );
    }
    prevTimestamp = c.timestamp_ms;
  }

  // Check typing speed from features_json (human range: 1-1000 CPM)
  // Also track speeds for drift detection
  let prevSpeed: number | undefined;
  let prevSpeedSeq: number | undefined;
  for (const c of behavioralCommitments) {
    if (c.features_json) {
      try {
        const features = JSON.parse(c.features_json);
        const speed = features.typing_speed_cpm ?? features.tier1?.typing_speed_cpm;
        if (speed !== undefined) {
          if (speed < 1 || speed > 1000) {
            warnings.push(
              `Typing speed at C${c.sequence_num} is ${speed} CPM — outside human range (1-1000)`,
            );
          }
          // Feature drift detection: flag 3x+ speed changes between consecutive checkpoints
          if (prevSpeed !== undefined && prevSpeed > 0 && speed > 0) {
            const ratio = speed / prevSpeed;
            if (ratio >= 3 || ratio <= 1 / 3) {
              warnings.push(
                `Typing speed changed dramatically between C${prevSpeedSeq} and C${c.sequence_num}: ${Math.round(prevSpeed)} CPM → ${Math.round(speed)} CPM`,
              );
            }
          }
          prevSpeed = speed;
          prevSpeedSeq = c.sequence_num;
        }
      } catch {
        // features_json not parseable — skip
      }
    }
  }

  // Session duration plausibility: check if session is implausibly short for content length
  if (bundle.commitments.length >= 2) {
    const firstTs = bundle.commitments[0].timestamp_ms;
    const lastTs = bundle.commitments[bundle.commitments.length - 1].timestamp_ms;
    const durationMs = lastTs - firstTs;

    // Estimate content length from last behavioral commitment's document_length
    let contentLength = 0;
    for (let i = behavioralCommitments.length - 1; i >= 0; i--) {
      if (behavioralCommitments[i].document_length !== undefined) {
        contentLength = behavioralCommitments[i].document_length!;
        break;
      }
    }

    if (durationMs < 5000 && contentLength > 100) {
      warnings.push(
        `Session duration (${durationMs}ms) is implausibly short for content length (${contentLength} chars)`,
      );
    }
  }

  // Check session_start_timestamp is not in the future relative to created_at
  if (bundle.device_attestation?.session_binding?.session_start_timestamp && bundle.created_at) {
    const sessionStart = new Date(bundle.device_attestation.session_binding.session_start_timestamp).getTime();
    const createdAt = new Date(bundle.created_at).getTime();
    if (!isNaN(sessionStart) && !isNaN(createdAt) && sessionStart > createdAt) {
      warnings.push(
        "Session start timestamp is after bundle created_at — timestamps may be fabricated",
      );
    }
  }
}

function estimateContentLength(
  behavioralCommitments: ProofBundleCommitment[],
  bundle: ProofBundle,
): number {
  // Use the last behavioral commitment's document_length if available
  for (let i = behavioralCommitments.length - 1; i >= 0; i--) {
    if (behavioralCommitments[i].document_length !== undefined) {
      return behavioralCommitments[i].document_length!;
    }
  }
  // Fallback: use total keystroke count as rough estimate
  return 0;
}
