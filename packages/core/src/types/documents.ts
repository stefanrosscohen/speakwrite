export interface Document {
  id: string;
  title: string;
  content_json: string | null;
  content_hash: string | null;
  word_count: number;
  created_at: string;
  updated_at: string;
}

export interface Session {
  id: string;
  document_id: string;
  started_at: string;
  ended_at: string | null;
  keystroke_count: number;
  status: string;
}

export interface CommitmentEntry {
  id?: number;
  document_id: string;
  sequence_num: number;
  commitment_hash: string;
  previous_hash: string | null;
  nonce: string;
  timestamp_ms: number;
  commitment_type: string;
  content_hash: string | null;
}
