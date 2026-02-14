export interface SpeakwriteProofRecord {
  $type: "io.speakwrite.proof";
  contentHash: string;
  bindingHash: string;
  chainLength: number;
  totalKeystrokes: number;
  proofBundle: string;
  verifierUrl: string;
  createdAt: string;
}

export interface ATProtoPostResult {
  uri: string;
  cid: string;
}
