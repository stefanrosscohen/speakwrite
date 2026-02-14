interface VerifyFormProps {
  content: string;
  bundleJson: string;
  onContentChange: (value: string) => void;
  onBundleJsonChange: (value: string) => void;
  onVerify: () => void;
  verifying: boolean;
}

const textareaStyle = {
  width: "100%",
  minHeight: "120px",
  padding: "12px",
  fontSize: "13px",
  fontFamily: '"SF Mono", "Fira Code", "Consolas", monospace',
  lineHeight: "1.5",
  borderRadius: "8px",
  border: "1px solid var(--border)",
  background: "var(--bg-secondary)",
  color: "var(--text-primary)",
  outline: "none",
  resize: "vertical" as const,
};

export function VerifyForm({
  content,
  bundleJson,
  onContentChange,
  onBundleJsonChange,
  onVerify,
  verifying,
}: VerifyFormProps) {
  return (
    <div className="flex flex-col gap-4">
      <div>
        <label
          className="block text-sm font-medium mb-1.5"
          style={{ color: "var(--text-secondary)" }}
        >
          Document Content
        </label>
        <textarea
          style={textareaStyle}
          placeholder="Paste the original document text here..."
          value={content}
          onChange={(e) => onContentChange(e.target.value)}
        />
      </div>

      <div>
        <label
          className="block text-sm font-medium mb-1.5"
          style={{ color: "var(--text-secondary)" }}
        >
          Proof Bundle (JSON)
        </label>
        <textarea
          style={{ ...textareaStyle, minHeight: "160px" }}
          placeholder='Paste the proof bundle JSON here, or load from an at:// URI...'
          value={bundleJson}
          onChange={(e) => onBundleJsonChange(e.target.value)}
        />
      </div>

      <button
        onClick={onVerify}
        disabled={verifying || !content.trim() || !bundleJson.trim()}
        style={{
          width: "100%",
          padding: "10px",
          fontSize: "14px",
          fontWeight: 600,
          borderRadius: "8px",
          border: "none",
          cursor: verifying ? "not-allowed" : "pointer",
          background: verifying ? "var(--border)" : "var(--accent)",
          color: "#fff",
          opacity: verifying || !content.trim() || !bundleJson.trim() ? 0.5 : 1,
        }}
      >
        {verifying ? "Verifying..." : "Verify Proof"}
      </button>
    </div>
  );
}
