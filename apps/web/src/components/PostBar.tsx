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
        message: `Posted with ${bundle.commitments.length} commitments and ${bundle.total_keystroke_count} keystrokes`,
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
          className="px-4 py-2 text-xs"
          style={{
            color: status.type === "success" ? "var(--success)" : "#ef4444",
            background:
              status.type === "success"
                ? "rgba(72, 187, 120, 0.1)"
                : "rgba(239, 68, 68, 0.1)",
          }}
        >
          {status.message}
        </div>
      )}

      {/* Post bar */}
      <div className="flex items-center justify-between px-4 py-3">
        <span
          className="text-xs"
          style={{ color: "var(--text-secondary)" }}
        >
          {wordCount > 0
            ? `${wordCount.toLocaleString()} word${wordCount !== 1 ? "s" : ""}`
            : "Start writing..."}
        </span>
        <button
          onClick={handlePost}
          disabled={publishing || wordCount === 0}
          className="px-6 py-2 rounded-full text-sm font-semibold transition-opacity"
          style={{
            background: "var(--accent)",
            color: "#fff",
            border: "none",
            opacity: publishing || wordCount === 0 ? 0.4 : 1,
            cursor: publishing || wordCount === 0 ? "default" : "pointer",
          }}
        >
          {publishing ? "Posting..." : "Post"}
        </button>
      </div>
    </div>
  );
}
