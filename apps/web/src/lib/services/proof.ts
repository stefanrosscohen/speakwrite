import { db } from "../db";
import Dexie from "dexie";
import {
  sha256Hex,
  contentBindingHash,
  hexEncode,
  randomNonce,
  commitmentHash,
  type ProofBundle,
  type ProofBundleCommitment,
  type DeviceAttestation,
} from "@speakwrite/core";
import { getActiveDocumentId, getActiveSessionId } from "./session";
import {
  isNativeShell,
  signFinalBinding,
  getAttestationEnvelope,
} from "./device-attestation";

export async function createContentBinding(content: string): Promise<{
  binding_hash: string;
  content_hash: string;
}> {
  const docId = getActiveDocumentId();
  if (!docId) throw new Error("No active document");

  const contentHash = await sha256Hex(content);

  // Get all commitments for this document
  const commitments = await db.commitments
    .where("[document_id+sequence_num]")
    .between([docId, Dexie.minKey], [docId, Dexie.maxKey])
    .toArray();

  const behavioralCommitments = commitments.filter(
    (c) => c.commitment_type === "behavioral",
  );
  if (behavioralCommitments.length === 0) {
    throw new Error("No behavioral commitments — checkpoint first");
  }

  const chainTip =
    behavioralCommitments[behavioralCommitments.length - 1].commitment_hash;
  const bindingHash = await contentBindingHash(chainTip, contentHash);
  const nextSequence = commitments.length;

  // Store content-binding commitment
  await db.commitments.add({
    document_id: docId,
    sequence_num: nextSequence,
    commitment_hash: bindingHash,
    previous_hash: chainTip,
    nonce: "",
    timestamp_ms: Date.now(),
    commitment_type: "content_binding",
    content_hash: contentHash,
    feature_json: "{}",
  });

  // Update document content hash
  await db.documents.update(docId, { content_hash: contentHash });

  return { binding_hash: bindingHash, content_hash: contentHash };
}

export async function exportProofBundle(): Promise<ProofBundle> {
  const docId = getActiveDocumentId();
  const sessionId = getActiveSessionId();
  if (!docId || !sessionId) throw new Error("No active session");

  const doc = await db.documents.get(docId);
  if (!doc) throw new Error("Document not found");

  // Count total keystrokes across all sessions for this document
  const sessions = await db.sessions
    .where("document_id")
    .equals(docId)
    .toArray();
  let totalKeystrokes = 0;
  for (const s of sessions) {
    totalKeystrokes += await db.keystrokes
      .where("session_id")
      .equals(s.id)
      .count();
  }

  // Get all commitments
  const commitments = await db.commitments
    .where("[document_id+sequence_num]")
    .between([docId, Dexie.minKey], [docId, Dexie.maxKey])
    .toArray();

  if (commitments.length === 0) {
    throw new Error("No commitments — checkpoint first");
  }

  // Ensure there's a content binding
  const hasBinding = commitments.some(
    (c) => c.commitment_type === "content_binding",
  );
  if (!hasBinding) {
    throw new Error("No content binding — bind content first");
  }

  const lastBinding = commitments
    .filter((c) => c.commitment_type === "content_binding")
    .pop()!;

  const bundleCommitments: ProofBundleCommitment[] = commitments.map((c) => ({
    sequence_num: c.sequence_num,
    commitment_hash: c.commitment_hash,
    previous_hash: c.previous_hash,
    nonce: c.nonce,
    timestamp_ms: c.timestamp_ms,
    commitment_type: c.commitment_type,
    content_hash: c.content_hash,
  }));

  const contentHash = doc.content_hash ?? lastBinding.content_hash ?? "";
  const bindingHash = lastBinding.commitment_hash;

  const bundle: ProofBundle = {
    version: "1.0.0",
    document_id: docId,
    content_hash: contentHash,
    commitments: bundleCommitments,
    binding_hash: bindingHash,
    total_keystroke_count: totalKeystrokes,
    created_at: new Date().toISOString(),
  };

  // If running in the iOS native shell, sign the final binding and attach attestation
  if (isNativeShell()) {
    try {
      // Sign the final content binding with Secure Enclave
      await signFinalBinding(contentHash, bindingHash);

      // Get the full attestation envelope (includes all checkpoint sigs + certificate)
      const envelope = await getAttestationEnvelope();
      if (envelope) {
        bundle.device_attestation = {
          platform: envelope.platform as DeviceAttestation["platform"],
          attestation_type: envelope.attestationType,
          attestation_level: envelope.attestationLevel as DeviceAttestation["attestation_level"],
          device_public_key: envelope.devicePublicKey,
          app_id: envelope.appId,
          attestation_certificate: envelope.attestationCertificate,
          session_binding: envelope.sessionBinding
            ? {
                session_id: envelope.sessionBinding.sessionId,
                biometric_gate: envelope.sessionBinding.biometricGate,
                session_start_signature: envelope.sessionBinding.sessionStartSignature,
              }
            : undefined,
          checkpoint_signatures: (envelope.checkpointSignatures ?? []).map((c) => ({
            sequence_num: c.sequenceNum,
            commitment_hash: c.commitmentHash,
            signature: c.signature,
          })),
        };
      }
    } catch (e) {
      // Attestation failed — still export the bundle without it
      console.warn("Device attestation failed, exporting without:", e);
    }
  }

  return bundle;
}
