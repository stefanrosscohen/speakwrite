import { create } from "zustand";

interface CommitmentEntry {
  sequence_num: number;
  commitment_hash: string;
  previous_hash: string | null;
  timestamp_ms: number;
}

interface AppState {
  // Session
  sessionId: string | null;
  documentId: string | null;
  sessionActive: boolean;
  sessionStartTime: number | null;

  // Proof status
  status: string;
  keystrokeCount: number;
  commitmentCount: number;
  commitments: CommitmentEntry[];
  sessionDurationMs: number;

  // Editor
  wordCount: number;
  paragraphCount: number;

  // AT Protocol
  atprotoHandle: string | null;
  atprotoDid: string | null;
  atprotoLoading: boolean;

  // Actions
  setSession: (sessionId: string, documentId: string) => void;
  clearSession: () => void;
  incrementKeystrokes: (count: number) => void;
  setProofStatus: (status: {
    status: string;
    keystroke_count: number;
    commitment_count: number;
    session_duration_ms: number;
    commitments: CommitmentEntry[];
  }) => void;
  setEditorStats: (wordCount: number, paragraphCount: number) => void;
  addCommitment: (entry: CommitmentEntry) => void;
  setATProto: (handle: string, did: string) => void;
  setATProtoLoading: (loading: boolean) => void;
  clearATProto: () => void;
}

export const useAppStore = create<AppState>((set) => ({
  sessionId: null,
  documentId: null,
  sessionActive: false,
  sessionStartTime: null,

  status: "idle",
  keystrokeCount: 0,
  commitmentCount: 0,
  commitments: [],
  sessionDurationMs: 0,

  wordCount: 0,
  paragraphCount: 0,

  atprotoHandle: null,
  atprotoDid: null,
  atprotoLoading: true,

  setSession: (sessionId, documentId) =>
    set({
      sessionId,
      documentId,
      sessionActive: true,
      sessionStartTime: Date.now(),
      status: "capturing",
    }),

  clearSession: () =>
    set({
      sessionId: null,
      sessionActive: false,
      status: "idle",
    }),

  incrementKeystrokes: (count) =>
    set((s) => ({ keystrokeCount: s.keystrokeCount + count })),

  setProofStatus: (ps) =>
    set({
      status: ps.status,
      keystrokeCount: ps.keystroke_count,
      commitmentCount: ps.commitment_count,
      sessionDurationMs: ps.session_duration_ms,
      commitments: ps.commitments,
    }),

  setEditorStats: (wordCount, paragraphCount) =>
    set({ wordCount, paragraphCount }),

  addCommitment: (entry) =>
    set((s) => ({
      commitments: [...s.commitments, entry],
      commitmentCount: s.commitmentCount + 1,
    })),

  setATProto: (handle, did) =>
    set({ atprotoHandle: handle, atprotoDid: did }),

  setATProtoLoading: (loading) => set({ atprotoLoading: loading }),

  clearATProto: () =>
    set({ atprotoHandle: null, atprotoDid: null }),
}));
