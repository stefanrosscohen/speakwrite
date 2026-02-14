// Types
export type {
  KeystrokeEvent,
  DigraphStats,
  Tier1Features,
  Tier2Features,
  FeatureVector,
  Document,
  Session,
  CommitmentEntry,
  ProofBundleCommitment,
  ProofBundle,
  VerifyResult,
  DeviceAttestation,
  DeviceAttestationCheckpoint,
  SpeakwriteProofRecord,
  ATProtoPostResult,
} from "./types";

// Crypto
export {
  sha256Hex,
  commitmentHash,
  contentBindingHash,
  hexEncode,
  hexDecode,
} from "./crypto/hashing";
export { randomNonce } from "./crypto/nonce";

// Features
export { extractTier1 } from "./features/tier1";
export { extractTier2 } from "./features/tier2";
export { digraphStatsFromSamples } from "./features/vector";
export { mean, stdDev, median, percentile } from "./features/utils";

// Capture
export { validateEvent } from "./capture/validator";

// Verification
export { verifyProofBundle } from "./verification/bundle";
export { verifyChainIntegrity } from "./verification/chain";
export type { ChainIntegrityResult } from "./verification/chain";

// AT Protocol
export { createProofRecord, createProofPost } from "./atproto/client";
export { SPEAKWRITE_PROOF_LEXICON, PROOF_COLLECTION } from "./atproto/lexicon";
