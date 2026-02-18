import { AtpAgent } from '@atproto/api';

export interface ProofRecord {
  postUri: string;
  keyId: string;
  contentHash: string;
  attestationObject: string;
  assertion: string;
  appId: string;
  mediaHashes?: string[];
  createdAt?: string;
}

export interface VerificationResult {
  verified: boolean;
  reason?: string;
}

export interface PostTarget {
  uri: string;
  cid: string;
  authorDid: string;
  text: string;
  handle: string;
  rkey: string;
}

export interface MentionNotification {
  uri: string;
  cid: string;
  author: { did: string; handle: string };
  record: {
    text: string;
    reply?: {
      parent: { uri: string; cid: string };
      root: { uri: string; cid: string };
    };
    facets?: Array<{
      index: { byteStart: number; byteEnd: number };
      features: Array<{ $type: string; did?: string }>;
    }>;
    createdAt: string;
  };
  reason: string;
  isRead: boolean;
  indexedAt: string;
}

export type BotAgent = AtpAgent;
