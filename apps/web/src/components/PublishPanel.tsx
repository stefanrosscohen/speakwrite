import { useState } from "react";
import { useAppStore } from "../stores/app-store";
import { checkpointSession } from "../lib/services/session";
import { createContentBinding, exportProofBundle } from "../lib/services/proof";
import {
  signIn,
  logout,
  publishProofPost,
} from "../lib/services/atproto";
import type { ProofBundle } from "@speakwrite/core";

type Tab = "bluesky" | "export";

export function PublishPanel() {
  const [tab, setTab] = useState<Tab>("bluesky");
  const [publishing, setPublishing] = useState(false);
  const [signingIn, setSigningIn] = useState(false);
  const [result, setResult] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const [handle, setHandle] = useState("");
  const atprotoHandle = useAppStore((s) => s.atprotoHandle);
  const atprotoLoading = useAppStore((s) => s.atprotoLoading);
  const setATProto = useAppStore((s) => s.setATProto);
  const clearATProto = useAppStore((s) => s.clearATProto);

  const clearStatus = () => {
    setResult(null);
    setError(null);
  };

  const handleSignIn = async () => {
    clearStatus();
    if (!handle.trim()) return;
    setSigningIn(true);
    try {
      await signIn(handle.trim());
      // Browser redirects away — this line won't execute
    } catch (e) {
      setSigningIn(false);
      setError(String(e));
    }
  };

  const handleLogout = async () => {
    clearStatus();
    await logout();
    clearATProto();
  };

  const ensureBundleReady = async (
    editorContent: string,
  ): Promise<ProofBundle> => {
    try {
      await checkpointSession();
    } catch {
      // May fail if no new keystrokes — that's fine
    }
    await createContentBinding(editorContent);
    return exportProofBundle();
  };

  const handlePublishToBluesky = async () => {
    clearStatus();
    setPublishing(true);
    try {
      const editorEl = document.querySelector(".tiptap");
      const content = editorEl?.textContent ?? "";
      if (!content.trim()) {
        throw new Error("Editor is empty — write something first");
      }

      const bundle = await ensureBundleReady(content);
      const result = await publishProofPost(bundle, content);

      setResult(`Proof published! AT URI: ${result.uri}`);
    } catch (e) {
      setError(String(e));
    } finally {
      setPublishing(false);
    }
  };

  const handleExportBundle = async () => {
    clearStatus();
    try {
      const editorEl = document.querySelector(".tiptap");
      const content = editorEl?.textContent ?? "";
      if (!content.trim()) {
        throw new Error("Editor is empty — write something first");
      }

      const bundle = await ensureBundleReady(content);
      const json = JSON.stringify(bundle, null, 2);
      await navigator.clipboard.writeText(json);
      setResult(
        `Proof bundle copied (${bundle.commitments.length} commitments, ${bundle.total_keystroke_count} keystrokes)`,
      );
    } catch (e) {
      setError(String(e));
    }
  };

  const tabStyle = (t: Tab) => ({
    padding: "4px 10px",
    fontSize: "11px",
    borderRadius: "4px",
    border: "none",
    cursor: "pointer" as const,
    background: tab === t ? "var(--accent)" : "transparent",
    color: tab === t ? "#fff" : "var(--text-secondary)",
  });

  const inputStyle = {
    width: "100%",
    padding: "6px 8px",
    fontSize: "11px",
    borderRadius: "4px",
    border: "1px solid var(--border)",
    background: "var(--bg-primary)",
    color: "var(--text-primary)",
    outline: "none",
  };

  const buttonStyle = {
    width: "100%",
    padding: "8px",
    fontSize: "12px",
    fontWeight: 600 as const,
    borderRadius: "6px",
    border: "none",
    cursor: publishing ? ("not-allowed" as const) : ("pointer" as const),
    background: publishing ? "var(--border)" : "var(--accent)",
    color: "#fff",
    opacity: publishing ? 0.6 : 1,
  };

  return (
    <div style={{ marginTop: "16px" }}>
      <div
        style={{
          fontSize: "11px",
          fontWeight: 600,
          textTransform: "uppercase" as const,
          letterSpacing: "0.05em",
          color: "var(--text-secondary)",
          marginBottom: "8px",
        }}
      >
        Publish
      </div>

      {/* Tab bar */}
      <div style={{ display: "flex", gap: "4px", marginBottom: "12px" }}>
        <button
          style={tabStyle("bluesky")}
          onClick={() => {
            setTab("bluesky");
            clearStatus();
          }}
        >
          AT Protocol
        </button>
        <button
          style={tabStyle("export")}
          onClick={() => {
            setTab("export");
            clearStatus();
          }}
        >
          Export
        </button>
      </div>

      {/* AT Protocol tab */}
      {tab === "bluesky" && (
        <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
          {atprotoLoading ? (
            <div
              style={{
                fontSize: "11px",
                color: "var(--text-secondary)",
                padding: "8px 0",
              }}
            >
              Checking authentication...
            </div>
          ) : !atprotoHandle ? (
            <>
              <input
                style={inputStyle}
                type="text"
                placeholder="Handle (e.g. alice.bsky.social)"
                value={handle}
                onChange={(e) => setHandle(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") handleSignIn();
                }}
              />
              <button
                style={{
                  ...buttonStyle,
                  cursor: signingIn || !handle.trim() ? "not-allowed" : "pointer",
                  opacity: signingIn || !handle.trim() ? 0.6 : 1,
                }}
                onClick={handleSignIn}
                disabled={signingIn || !handle.trim()}
              >
                {signingIn ? "Redirecting..." : "Sign in with AT Protocol"}
              </button>
            </>
          ) : (
            <>
              <div
                style={{
                  display: "flex",
                  justifyContent: "space-between",
                  alignItems: "center",
                }}
              >
                <div
                  style={{
                    fontSize: "11px",
                    color: "var(--success)",
                  }}
                >
                  Signed in as @{atprotoHandle}
                </div>
                <button
                  style={{
                    fontSize: "10px",
                    color: "var(--text-secondary)",
                    background: "none",
                    border: "none",
                    cursor: "pointer",
                    textDecoration: "underline",
                    padding: 0,
                  }}
                  onClick={handleLogout}
                >
                  Sign out
                </button>
              </div>
              <button
                style={buttonStyle}
                onClick={handlePublishToBluesky}
                disabled={publishing}
              >
                {publishing ? "Publishing..." : "Publish Proof"}
              </button>
            </>
          )}
        </div>
      )}

      {/* Export tab */}
      {tab === "export" && (
        <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
          <p
            style={{ fontSize: "11px", color: "var(--text-secondary)", margin: 0 }}
          >
            Export your proof bundle for external verification.
          </p>
          <button
            style={{
              ...buttonStyle,
              background: publishing ? "var(--border)" : "var(--bg-surface)",
              color: "var(--text-primary)",
              border: "1px solid var(--border)",
            }}
            onClick={handleExportBundle}
          >
            Copy Proof Bundle (JSON)
          </button>
        </div>
      )}

      {/* Status messages */}
      {result && (
        <div
          style={{
            marginTop: "8px",
            padding: "6px 8px",
            fontSize: "11px",
            borderRadius: "4px",
            background: "rgba(34, 197, 94, 0.1)",
            color: "#22c55e",
            wordBreak: "break-all",
          }}
        >
          {result}
        </div>
      )}
      {error && (
        <div
          style={{
            marginTop: "8px",
            padding: "6px 8px",
            fontSize: "11px",
            borderRadius: "4px",
            background: "rgba(239, 68, 68, 0.1)",
            color: "#ef4444",
            wordBreak: "break-all",
          }}
        >
          {error}
        </div>
      )}
    </div>
  );
}
