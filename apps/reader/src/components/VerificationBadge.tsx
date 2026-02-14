import type { VerificationStatus } from "../lib/verification";

interface Props {
  status: VerificationStatus;
}

export function VerificationBadge({ status }: Props) {
  if (status.type === "verifying") {
    return (
      <div
        style={{
          fontFamily: "var(--font-mono)",
          fontSize: "10px",
          color: "var(--text-secondary)",
          padding: "4px 8px",
          border: "1px solid var(--border)",
          display: "inline-block",
        }}
      >
        verifying...
      </div>
    );
  }

  if (status.type === "footer_only") {
    return (
      <div
        style={{
          fontFamily: "var(--font-mono)",
          fontSize: "10px",
          color: "var(--warning)",
          padding: "4px 8px",
          border: "1px solid rgba(255, 170, 0, 0.3)",
          background: "rgba(255, 170, 0, 0.05)",
          display: "inline-flex",
          gap: "8px",
          alignItems: "center",
        }}
      >
        <span>{status.keystrokes.toLocaleString()} keystrokes</span>
        <span style={{ color: "var(--text-secondary)" }}>/</span>
        <span>{status.commitments} commitments</span>
      </div>
    );
  }

  if (status.type === "verified") {
    return (
      <div
        style={{
          fontFamily: "var(--font-mono)",
          fontSize: "10px",
          color: "var(--accent)",
          padding: "4px 8px",
          border: "1px solid rgba(0, 255, 65, 0.3)",
          background: "rgba(0, 255, 65, 0.05)",
          display: "inline-flex",
          gap: "8px",
          alignItems: "center",
        }}
      >
        <span>VERIFIED</span>
        <span style={{ color: "var(--text-secondary)" }}>/</span>
        <span>{status.result.chain_length} commitments</span>
      </div>
    );
  }

  if (status.type === "failed") {
    return (
      <div
        style={{
          fontFamily: "var(--font-mono)",
          fontSize: "10px",
          color: "var(--danger)",
          padding: "4px 8px",
          border: "1px solid rgba(255, 51, 51, 0.3)",
          background: "rgba(255, 51, 51, 0.05)",
          display: "inline-block",
        }}
      >
        VERIFICATION FAILED
      </div>
    );
  }

  return null;
}
