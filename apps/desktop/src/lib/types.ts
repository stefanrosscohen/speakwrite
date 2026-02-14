export interface KeystrokeEvent {
  event_type: string;
  key: string;
  code: string;
  timestamp: number;
  shift_key: boolean;
  ctrl_key: boolean;
  alt_key: boolean;
  meta_key: boolean;
  repeat: boolean;
  is_composing: boolean;
  sequence_number: number;
}

export interface StartSessionResult {
  session_id: string;
  document_id: string;
}

export interface CheckpointResult {
  commitment_hash: string;
  sequence: number;
  keystroke_count: number;
}

export interface CommitmentEntry {
  sequence_num: number;
  commitment_hash: string;
  previous_hash: string | null;
  timestamp_ms: number;
}

export interface ProofStatus {
  status: string;
  keystroke_count: number;
  commitment_count: number;
  session_duration_ms: number;
  commitments: CommitmentEntry[];
}

export interface DocumentInfo {
  id: string;
  title: string;
  content_json: string | null;
  content_hash: string | null;
  word_count: number;
  created_at: string;
  updated_at: string;
}

export interface DocumentListItem {
  id: string;
  title: string;
  word_count: number;
  updated_at: string;
}

export interface PublishResult {
  url: string;
  platform: string;
  content_binding_hash: string;
  content_hash: string;
}

export interface VerifyResult {
  valid: boolean;
  content_hash_matches: boolean;
  chain_length: number;
  binding_hash: string | null;
  expected_content_hash: string | null;
  actual_content_hash: string;
  message: string;
}
