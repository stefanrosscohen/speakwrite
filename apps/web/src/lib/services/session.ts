import Dexie from "dexie";
import { db } from "../db";
import type { KeystrokeEvent } from "@speakwrite/core";
import {
  extractTier1,
  extractTier2,
  sha256Hex,
  commitmentHash,
  contentBindingHash,
  randomNonce,
  hexEncode,
} from "@speakwrite/core";
import {
  isNativeShell,
  startAttestedSession,
  signCheckpoint,
} from "./device-attestation";

let activeSessionId: string | null = null;
let activeDocumentId: string | null = null;

export async function startSession(documentId?: string): Promise<{
  session_id: string;
  document_id: string;
}> {
  const docId = documentId ?? crypto.randomUUID();
  const sessionId = crypto.randomUUID();

  // Ensure document exists
  const existingDoc = await db.documents.get(docId);
  if (!existingDoc) {
    const now = new Date().toISOString();
    await db.documents.add({
      id: docId,
      title: "Untitled",
      content_json: null,
      content_hash: null,
      word_count: 0,
      created_at: now,
      updated_at: now,
    });
  }

  await db.sessions.add({
    id: sessionId,
    document_id: docId,
    status: "active",
    started_at: new Date().toISOString(),
    ended_at: null,
  });

  activeSessionId = sessionId;
  activeDocumentId = docId;

  // If on iOS, start an attested session (triggers Face ID)
  if (isNativeShell()) {
    try {
      await startAttestedSession();
    } catch (e) {
      console.warn("Device attestation session start failed:", e);
    }
  }

  return { session_id: sessionId, document_id: docId };
}

export async function endSession(): Promise<void> {
  if (!activeSessionId) return;

  await db.sessions.update(activeSessionId, {
    status: "completed",
    ended_at: new Date().toISOString(),
  });

  activeSessionId = null;
}

export function getActiveSessionId(): string | null {
  return activeSessionId;
}

export function getActiveDocumentId(): string | null {
  return activeDocumentId;
}

export async function recordKeystrokeBatch(events: KeystrokeEvent[]): Promise<void> {
  if (!activeSessionId) return;

  const rows = events.map((e) => ({
    session_id: activeSessionId!,
    event_type: e.event_type,
    key: e.key,
    code: e.code,
    timestamp_ms: e.timestamp,
    shift_key: e.shift_key,
    ctrl_key: e.ctrl_key,
    alt_key: e.alt_key,
    meta_key: e.meta_key,
    repeat: e.repeat,
    is_composing: e.is_composing,
    sequence_number: e.sequence_number,
  }));

  await db.keystrokes.bulkAdd(rows);
}

export async function checkpointSession(): Promise<{
  commitment_hash: string;
  sequence: number;
  keystroke_count: number;
}> {
  if (!activeSessionId || !activeDocumentId) {
    throw new Error("No active session");
  }

  // Gather keystrokes from this session
  const keystrokes = await db.keystrokes
    .where("session_id")
    .equals(activeSessionId)
    .toArray();

  if (keystrokes.length === 0) {
    throw new Error("No keystrokes to checkpoint");
  }

  // Convert DB rows to KeystrokeEvent[]
  const events: KeystrokeEvent[] = keystrokes.map((k) => ({
    event_type: k.event_type,
    key: k.key,
    code: k.code,
    timestamp: k.timestamp_ms,
    shift_key: k.shift_key,
    ctrl_key: k.ctrl_key,
    alt_key: k.alt_key,
    meta_key: k.meta_key,
    repeat: k.repeat,
    is_composing: k.is_composing,
    sequence_number: k.sequence_number,
  }));

  // Extract features
  const tier1 = extractTier1(events);
  const tier2 = extractTier2(events);

  // Save feature vector
  const vectorId = crypto.randomUUID();
  await db.feature_vectors.add({
    id: vectorId,
    session_id: activeSessionId,
    tier1_json: JSON.stringify(tier1),
    tier2_json: JSON.stringify(tier2),
    created_at: new Date().toISOString(),
  });

  // Get previous commitment for this document
  const prevCommitments = await db.commitments
    .where("[document_id+sequence_num]")
    .between(
      [activeDocumentId, Dexie.minKey],
      [activeDocumentId, Dexie.maxKey],
    )
    .toArray();

  const behavioralCommitments = prevCommitments.filter(
    (c) => c.commitment_type === "behavioral",
  );
  const previousHash =
    behavioralCommitments.length > 0
      ? behavioralCommitments[behavioralCommitments.length - 1].commitment_hash
      : null;
  const nextSequence = prevCommitments.length;

  // Build commitment
  const featureData = JSON.stringify({ tier1, tier2 });
  const nonce = randomNonce();
  const dataBytes = new TextEncoder().encode(featureData);
  const hash = await commitmentHash(previousHash, nonce, dataBytes);

  await db.commitments.add({
    document_id: activeDocumentId,
    sequence_num: nextSequence,
    commitment_hash: hash,
    previous_hash: previousHash,
    nonce: hexEncode(nonce),
    timestamp_ms: Date.now(),
    commitment_type: "behavioral",
    content_hash: null,
    feature_json: featureData,
  });

  // If on iOS, sign this checkpoint with the Secure Enclave
  if (isNativeShell()) {
    try {
      await signCheckpoint(hash, nextSequence);
    } catch (e) {
      console.warn("Checkpoint signing failed:", e);
    }
  }

  return {
    commitment_hash: hash,
    sequence: nextSequence,
    keystroke_count: keystrokes.length,
  };
}

export async function getProofStatus(): Promise<{
  status: string;
  keystroke_count: number;
  commitment_count: number;
  session_duration_ms: number;
  commitments: Array<{
    sequence_num: number;
    commitment_hash: string;
    previous_hash: string | null;
    timestamp_ms: number;
  }>;
}> {
  if (!activeSessionId || !activeDocumentId) {
    return {
      status: "idle",
      keystroke_count: 0,
      commitment_count: 0,
      session_duration_ms: 0,
      commitments: [],
    };
  }

  const session = await db.sessions.get(activeSessionId);
  if (!session) {
    return {
      status: "idle",
      keystroke_count: 0,
      commitment_count: 0,
      session_duration_ms: 0,
      commitments: [],
    };
  }

  const keystrokeCount = await db.keystrokes
    .where("session_id")
    .equals(activeSessionId)
    .count();

  const commitments = await db.commitments
    .where("[document_id+sequence_num]")
    .between(
      [activeDocumentId, Dexie.minKey],
      [activeDocumentId, Dexie.maxKey],
    )
    .toArray();

  const startTime = new Date(session.started_at).getTime();
  const durationMs = Date.now() - startTime;

  return {
    status: "capturing",
    keystroke_count: keystrokeCount,
    commitment_count: commitments.length,
    session_duration_ms: durationMs,
    commitments: commitments.map((c) => ({
      sequence_num: c.sequence_num,
      commitment_hash: c.commitment_hash,
      previous_hash: c.previous_hash,
      timestamp_ms: c.timestamp_ms,
    })),
  };
}
