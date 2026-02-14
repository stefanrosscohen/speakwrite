import { useState } from "react";
import { useAppStore } from "../stores/app-store";
import { checkpointSession } from "../lib/services/session";
import { createContentBinding, exportProofBundle } from "../lib/services/proof";
import { publishProofPost } from "../lib/services/atproto";

export function PostBar() {
  const [publishing, setPublishing] = useState(false);
  const [status, setStatus] = useState<{
    type: "success" | "error";
    message: string;
  } | null>(null);

  const wordCount = useAppStore((s) => s.wordCount);

  const handlePost = async () => {
    setStatus(null);
    setPublishing(true);
    try {
      const editorEl = document.querySelector(".tiptap");
      const content = editorEl?.textContent ?? "";
      if (!content.trim()) {
        throw new Error("Write something first");
      }

      // 1. Create a final checkpoint
      try {
        await checkpointSession();
      } catch {
        // May fail if no new keystrokes — that's fine
      }

      // 2. Bind content to the commitment chain
      await createContentBinding(content);

      // 3. Export proof bundle (includes device attestation on iOS)
      const bundle = await exportProofBundle();

      // 4. Publish as a Bluesky post
      await publishProofPost(bundle, content);

      setStatus({
        type: "success",
        message: `TRANSMITTED // ${bundle.commitments.length} commitments // ${bundle.total_keystroke_count} keystrokes`,
      });
    } catch (e) {
      setStatus({
        type: "error",
        message: String(e),
      });
    } finally {
      setPublishing(false);
    }
  };

  return (
    <div
      className="flex-shrink-0"
      style={{
        borderTop: "1px solid var(--border)",
        background: "var(--bg-secondary)",
      }}
    >
      {/* Status message */}
      {status && (
        <div
          style={{
            padding: "8px 16px",
            fontFamily: "var(--font-mono)",
            fontSize: "10px",
            letterSpacing: "0.05em",
            color: status.type === "success" ? "var(--accent)" : "var(--danger)",
            background:
              status.type === "success"
                ? "rgba(0, 255, 65, 0.05)"
                : "rgba(255, 51, 51, 0.05)",
            borderBottom: "1px solid var(--border)",
          }}
        >
          {status.type === "success" ? "> " : "ERR: "}
          {status.message}
        </div>
      )}

      {/* Post bar */}
      <div className="flex items-center justify-between px-4 py-3">
        <span
          style={{
            fontFamily: "var(--font-mono)",
            fontSize: "10px",
            color: "var(--text-secondary)",
            letterSpacing: "0.05em",
          }}
        >
          {wordCount > 0
            ? `${wordCount.toLocaleString()} words`
            : "_ _"}
        </span>
        <button
          onClick={handlePost}
          disabled={publishing || wordCount === 0}
          style={{
            fontFamily: "var(--font-mono)",
            fontSize: "11px",
            fontWeight: 600,
            letterSpacing: "0.1em",
            textTransform: "uppercase",
            padding: "8px 20px",
            background:
              publishing || wordCount === 0
                ? "transparent"
                : "var(--accent)",
            color:
              publishing || wordCount === 0
                ? "var(--text-secondary)"
                : "var(--bg-primary)",
            border:
              publishing || wordCount === 0
                ? "1px solid var(--border)"
                : "1px solid var(--accent)",
            borderRadius: "0",
            cursor: publishing || wordCount === 0 ? "default" : "pointer",
            transition: "all 0.15s",
          }}
        >
          {publishing ? "transmitting..." : "publish"}
        </button>
      </div>
    </div>
  );
}
