import { useEffect, useRef, useCallback } from "react";
import { useEditor, EditorContent } from "@tiptap/react";
import StarterKit from "@tiptap/starter-kit";
import Placeholder from "@tiptap/extension-placeholder";
import { KeystrokeObserver } from "../extensions/keystroke-observer";
import { startSession, endSession, checkpointSession, getProofStatus, saveDocument } from "../lib/commands";
import { useAppStore } from "../stores/app-store";

const CHECKPOINT_INTERVAL_MS = 5 * 60 * 1000; // 5 minutes
const STATUS_POLL_INTERVAL_MS = 1000; // 1 second
const AUTOSAVE_INTERVAL_MS = 30 * 1000; // 30 seconds

export function Editor() {
  const setSession = useAppStore((s) => s.setSession);
  const incrementKeystrokes = useAppStore((s) => s.incrementKeystrokes);
  const setProofStatus = useAppStore((s) => s.setProofStatus);
  const setEditorStats = useAppStore((s) => s.setEditorStats);
  const addCommitment = useAppStore((s) => s.addCommitment);

  const checkpointIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const statusPollRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const autosaveRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const handleKeystrokesBatched = useCallback(
    (count: number) => {
      incrementKeystrokes(count);
    },
    [incrementKeystrokes],
  );

  const editor = useEditor({
    extensions: [
      StarterKit,
      Placeholder.configure({
        placeholder: "Start writing...",
      }),
      KeystrokeObserver.configure({
        onKeystrokesBatched: handleKeystrokesBatched,
      }),
    ],
    content: "",
    editorProps: {
      attributes: {
        class: "tiptap",
      },
    },
    onUpdate: ({ editor }) => {
      const text = editor.getText();
      const words = text.trim() ? text.trim().split(/\s+/).length : 0;
      const paragraphs = editor.getJSON().content?.length ?? 0;
      setEditorStats(words, paragraphs);
    },
  });

  // Start session on mount
  useEffect(() => {
    let mounted = true;

    async function init() {
      try {
        const result = await startSession();
        if (mounted) {
          setSession(result.session_id, result.document_id);
        }
      } catch (e) {
        console.error("Failed to start session:", e);
      }
    }

    init();

    return () => {
      mounted = false;
      endSession().catch(console.error);
    };
  }, [setSession]);

  // Periodic checkpoints (every 5 minutes)
  useEffect(() => {
    checkpointIntervalRef.current = setInterval(async () => {
      try {
        const result = await checkpointSession();
        addCommitment({
          sequence_num: result.sequence,
          commitment_hash: result.commitment_hash,
          previous_hash: null,
          timestamp_ms: Date.now(),
        });
      } catch {
        // No events to checkpoint — that's fine
      }
    }, CHECKPOINT_INTERVAL_MS);

    return () => {
      if (checkpointIntervalRef.current) {
        clearInterval(checkpointIntervalRef.current);
      }
    };
  }, [addCommitment]);

  // Poll proof status every second
  useEffect(() => {
    statusPollRef.current = setInterval(async () => {
      try {
        const status = await getProofStatus();
        setProofStatus(status);
      } catch {
        // Ignore poll errors
      }
    }, STATUS_POLL_INTERVAL_MS);

    return () => {
      if (statusPollRef.current) {
        clearInterval(statusPollRef.current);
      }
    };
  }, [setProofStatus]);

  // Auto-save every 30 seconds
  useEffect(() => {
    autosaveRef.current = setInterval(() => {
      if (!editor) return;
      const json = JSON.stringify(editor.getJSON());
      const text = editor.getText();
      const words = text.trim() ? text.trim().split(/\s+/).length : 0;
      saveDocument(json, words).catch(() => {
        // Ignore save errors silently
      });
    }, AUTOSAVE_INTERVAL_MS);

    return () => {
      // Save on unmount
      if (editor) {
        const json = JSON.stringify(editor.getJSON());
        const text = editor.getText();
        const words = text.trim() ? text.trim().split(/\s+/).length : 0;
        saveDocument(json, words).catch(() => {});
      }
      if (autosaveRef.current) {
        clearInterval(autosaveRef.current);
      }
    };
  }, [editor]);

  return <EditorContent editor={editor} />;
}
