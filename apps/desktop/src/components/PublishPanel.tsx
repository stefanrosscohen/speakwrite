import { useState } from "react";
import {
  publishToNotion,
  publishToSubstack,
  exportHtml,
  exportProofBundle,
} from "../lib/commands";

type Tab = "notion" | "substack" | "export";

export function PublishPanel() {
  const [tab, setTab] = useState<Tab>("notion");
  const [publishing, setPublishing] = useState(false);
  const [result, setResult] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Notion fields
  const [notionApiKey, setNotionApiKey] = useState("");
  const [notionPageId, setNotionPageId] = useState("");

  // Substack fields
  const [substackSubdomain, setSubstackSubdomain] = useState("");
  const [substackCookie, setSubstackCookie] = useState("");

  const clearStatus = () => {
    setResult(null);
    setError(null);
  };

  const handleNotionPublish = async () => {
    clearStatus();
    setPublishing(true);
    try {
      const res = await publishToNotion(notionApiKey, notionPageId);
      setResult(res.url);
    } catch (e) {
      setError(String(e));
    } finally {
      setPublishing(false);
    }
  };

  const handleSubstackPublish = async () => {
    clearStatus();
    setPublishing(true);
    try {
      const res = await publishToSubstack(substackSubdomain, substackCookie);
      setResult(res.url);
    } catch (e) {
      setError(String(e));
    } finally {
      setPublishing(false);
    }
  };

  const handleExportHtml = async () => {
    clearStatus();
    try {
      const html = await exportHtml();
      await navigator.clipboard.writeText(html);
      setResult("HTML copied to clipboard");
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
        <button style={tabStyle("notion")} onClick={() => { setTab("notion"); clearStatus(); }}>
          Notion
        </button>
        <button style={tabStyle("substack")} onClick={() => { setTab("substack"); clearStatus(); }}>
          Substack
        </button>
        <button style={tabStyle("export")} onClick={() => { setTab("export"); clearStatus(); }}>
          Export
        </button>
      </div>

      {/* Notion tab */}
      {tab === "notion" && (
        <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
          <input
            style={inputStyle}
            type="password"
            placeholder="Notion API Key"
            value={notionApiKey}
            onChange={(e) => setNotionApiKey(e.target.value)}
          />
          <input
            style={inputStyle}
            type="text"
            placeholder="Parent Page ID"
            value={notionPageId}
            onChange={(e) => setNotionPageId(e.target.value)}
          />
          <button
            style={buttonStyle}
            onClick={handleNotionPublish}
            disabled={publishing || !notionApiKey || !notionPageId}
          >
            {publishing ? "Publishing..." : "Publish to Notion"}
          </button>
        </div>
      )}

      {/* Substack tab */}
      {tab === "substack" && (
        <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
          <input
            style={inputStyle}
            type="text"
            placeholder="Subdomain (e.g. yourname)"
            value={substackSubdomain}
            onChange={(e) => setSubstackSubdomain(e.target.value)}
          />
          <input
            style={inputStyle}
            type="password"
            placeholder="Session Cookie"
            value={substackCookie}
            onChange={(e) => setSubstackCookie(e.target.value)}
          />
          <button
            style={buttonStyle}
            onClick={handleSubstackPublish}
            disabled={publishing || !substackSubdomain || !substackCookie}
          >
            {publishing ? "Publishing..." : "Create Substack Draft"}
          </button>
        </div>
      )}

      {/* Export tab */}
      {tab === "export" && (
        <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
          <p style={{ fontSize: "11px", color: "var(--text-secondary)", margin: 0 }}>
            Export your document or proof bundle for external verification.
          </p>
          <button style={buttonStyle} onClick={handleExportHtml}>
            Copy HTML to Clipboard
          </button>
          <button
            style={{
              ...buttonStyle,
              background: publishing ? "var(--border)" : "var(--bg-surface)",
              color: "var(--text-primary)",
              border: "1px solid var(--border)",
            }}
            onClick={async () => {
              clearStatus();
              try {
                const bundle = await exportProofBundle();
                const json = JSON.stringify(bundle, null, 2);
                await navigator.clipboard.writeText(json);
                setResult(`Proof bundle copied (${bundle.commitments.length} commitments, ${bundle.total_keystroke_count} keystrokes)`);
              } catch (e) {
                setError(String(e));
              }
            }}
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
          {result.startsWith("http") ? (
            <a
              href={result}
              target="_blank"
              rel="noopener noreferrer"
              style={{ color: "#22c55e", textDecoration: "underline" }}
            >
              {result}
            </a>
          ) : (
            result
          )}
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
