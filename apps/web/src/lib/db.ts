import Dexie, { type EntityTable } from "dexie";

/** Mirrors the SQLite schema from the desktop app */

export interface DBDocument {
  id: string;
  title: string;
  content_json: string | null;
  content_hash: string | null;
  word_count: number;
  created_at: string;
  updated_at: string;
}

export interface DBSession {
  id: string;
  document_id: string;
  status: "active" | "completed";
  started_at: string;
  ended_at: string | null;
}

export interface DBKeystroke {
  id?: number; // auto-increment
  session_id: string;
  event_type: string;
  key: string;
  code: string;
  timestamp_ms: number;
  shift_key: boolean;
  ctrl_key: boolean;
  alt_key: boolean;
  meta_key: boolean;
  repeat: boolean;
  is_composing: boolean;
  sequence_number: number;
}

export interface DBFeatureVector {
  id: string;
  session_id: string;
  tier1_json: string;
  tier2_json: string;
  created_at: string;
}

export interface DBCommitment {
  id?: number; // auto-increment
  document_id: string;
  sequence_num: number;
  commitment_hash: string;
  previous_hash: string | null;
  nonce: string;
  timestamp_ms: number;
  commitment_type: string;
  content_hash: string | null;
  feature_json: string;
}

export interface DBSetting {
  key: string;
  value: string;
}

const db = new Dexie("speakwrite") as Dexie & {
  documents: EntityTable<DBDocument, "id">;
  sessions: EntityTable<DBSession, "id">;
  keystrokes: EntityTable<DBKeystroke, "id">;
  feature_vectors: EntityTable<DBFeatureVector, "id">;
  commitments: EntityTable<DBCommitment, "id">;
  settings: EntityTable<DBSetting, "key">;
};

db.version(1).stores({
  documents: "id, updated_at",
  sessions: "id, document_id, status",
  keystrokes: "++id, session_id, [session_id+timestamp_ms]",
  feature_vectors: "id, session_id",
  commitments: "++id, document_id, [document_id+sequence_num]",
  settings: "key",
});

export { db };
