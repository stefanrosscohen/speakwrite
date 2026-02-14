import { useEffect, useRef, useCallback } from "react";
import { useEditor, EditorContent } from "@tiptap/react";
import { BubbleMenu } from "@tiptap/react/menus";
import StarterKit from "@tiptap/starter-kit";
import Placeholder from "@tiptap/extension-placeholder";
import TaskList from "@tiptap/extension-task-list";
import TaskItem from "@tiptap/extension-task-item";
import { Table, TableRow, TableHeader, TableCell } from "@tiptap/extension-table";
import Image from "@tiptap/extension-image";
import TextAlign from "@tiptap/extension-text-align";
import Highlight from "@tiptap/extension-highlight";
import { Color } from "@tiptap/extension-color";
import { TextStyle } from "@tiptap/extension-text-style";
import Underline from "@tiptap/extension-underline";
import Link from "@tiptap/extension-link";
import Typography from "@tiptap/extension-typography";
import { KeystrokeObserver } from "../extensions/keystroke-observer";
import { SlashCommand } from "../extensions/slash-command";
import { Callout } from "../extensions/callout";
import { BubbleToolbar } from "./BubbleToolbar";
import {
  startSession,
  endSession,
  checkpointSession,
  getProofStatus,
} from "../lib/services/session";
import { saveDocument } from "../lib/services/document";
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
        placeholder: "begin typing...",
      }),
      KeystrokeObserver.configure({
        onKeystrokesBatched: handleKeystrokesBatched,
      }),

      // Notion-style extensions
      SlashCommand,
      Callout,
      TaskList,
      TaskItem.configure({ nested: true }),
      Table.configure({ resizable: true }),
      TableRow,
      TableHeader,
      TableCell,
      Image.configure({ inline: false, allowBase64: true }),
      TextAlign.configure({ types: ["heading", "paragraph"] }),
      Highlight.configure({ multicolor: true }),
      TextStyle,
      Color,
      Underline,
      Link.configure({
        openOnClick: false,
        autolink: true,
        defaultProtocol: "https",
      }),
      Typography,
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
      saveDocument(json, words).catch(() => {});
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

  return (
    <>
      {editor && (
        <BubbleMenu editor={editor}>
          <BubbleToolbar editor={editor} />
        </BubbleMenu>
      )}
      <EditorContent editor={editor} />
    </>
  );
}
