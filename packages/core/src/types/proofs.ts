export interface ProofBundleCommitment {
  sequence_num: number;
  commitment_hash: string;
  previous_hash: string | null;
  nonce: string;
  timestamp_ms: number;
  commitment_type: string;
  content_hash: string | null;
  // v2 fields — openable commitments + incremental content hashing
  features_json?: string;
  document_hash?: string;
  document_length?: number;
  keystroke_count?: number;
}

export interface DeviceAttestationCheckpoint {
  sequence_num: number;
  commitment_hash: string;
  signature: string;
}

export interface DeviceAttestation {
  platform: "apple" | "android" | "web";
  attestation_type: string;
  attestation_level: "none" | "software" | "hardware_unverified" | "hardware_verified" | "platform_attested";
  device_public_key: string;
  app_id: string;
  attestation_certificate?: string;
  session_binding?: {
    session_id: string;
    biometric_gate: boolean;
    session_start_signature?: string;
    session_start_timestamp?: string;
  };
  checkpoint_signatures: DeviceAttestationCheckpoint[];
  final_signature?: string;
}

export interface ProofBundle {
  version: string;
  document_id: string;
  content_hash: string;
  commitments: ProofBundleCommitment[];
  binding_hash: string;
  total_keystroke_count: number;
  created_at: string;
  device_attestation?: DeviceAttestation;
}

export interface VerifyResult {
  valid: boolean;
  content_hash_matches: boolean;
  chain_length: number;
  binding_hash: string | null;
  expected_content_hash: string | null;
  actual_content_hash: string;
  message: string;
  // v2 fields — attestation verification + consistency checks
  signatures_valid?: boolean;
  attestation_level?: string | null;
  signature_count?: number;
  consistency_warnings?: string[];
}
