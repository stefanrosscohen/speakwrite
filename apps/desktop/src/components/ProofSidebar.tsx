import { useAppStore } from "../stores/app-store";
import { checkpointSession } from "../lib/commands";
import { PublishPanel } from "./PublishPanel";

function formatDuration(ms: number): string {
  const totalSeconds = Math.floor(ms / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}:${seconds.toString().padStart(2, "0")}`;
}

function truncateHash(hash: string): string {
  return hash.slice(0, 8) + "...";
}

export function ProofSidebar() {
  const status = useAppStore((s) => s.status);
  const keystrokeCount = useAppStore((s) => s.keystrokeCount);
  const commitmentCount = useAppStore((s) => s.commitmentCount);
  const sessionDurationMs = useAppStore((s) => s.sessionDurationMs);
  const commitments = useAppStore((s) => s.commitments);

  const handleManualCheckpoint = async () => {
    try {
      await checkpointSession();
    } catch (e) {
      console.error("Checkpoint failed:", e);
    }
  };

  const statusColor =
    status === "capturing"
      ? "var(--success)"
      : status === "idle"
        ? "var(--text-secondary)"
        : "var(--accent)";

  return (
    <div
      className="w-72 flex-shrink-0 border-l p-4 flex flex-col gap-4 overflow-y-auto"
      style={{ borderColor: "var(--border)", background: "var(--bg-secondary)" }}
    >
      <h2
        className="text-sm font-semibold uppercase tracking-wider"
        style={{ color: "var(--text-secondary)" }}
      >
        Proof Status
      </h2>

      <div className="flex flex-col gap-3">
        <StatusItem label="Status">
          <span className="flex items-center gap-1.5">
            <span
              className="inline-block w-2 h-2 rounded-full"
              style={{ background: statusColor }}
            />
            <span className="capitalize">{status}</span>
          </span>
        </StatusItem>
        <StatusItem label="Keystrokes">
          <span className="font-mono">{keystrokeCount.toLocaleString()}</span>
        </StatusItem>
        <StatusItem label="Commitments">
          <span className="font-mono">{commitmentCount}</span>
        </StatusItem>
        <StatusItem label="Duration">
          <span className="font-mono">{formatDuration(sessionDurationMs)}</span>
        </StatusItem>
      </div>

      {status === "capturing" && keystrokeCount > 0 && (
        <button
          onClick={handleManualCheckpoint}
          className="mt-2 px-3 py-1.5 rounded text-xs font-medium transition-colors cursor-pointer"
          style={{
            background: "var(--bg-surface)",
            color: "var(--text-primary)",
            border: "1px solid var(--border)",
          }}
        >
          Manual Checkpoint
        </button>
      )}

      <div className="mt-4">
        <h3
          className="text-xs font-semibold uppercase tracking-wider mb-2"
          style={{ color: "var(--text-secondary)" }}
        >
          Commitment Chain
        </h3>
        {commitments.length === 0 ? (
          <div className="text-xs" style={{ color: "var(--text-secondary)" }}>
            No commitments yet. Write for 5 minutes or click "Manual Checkpoint" to create the first commitment.
          </div>
        ) : (
          <div className="flex flex-col gap-1">
            {commitments.map((c, i) => (
              <div
                key={c.sequence_num}
                className="flex items-center gap-2 text-xs font-mono"
                style={{ color: "var(--text-primary)" }}
              >
                <span style={{ color: "var(--text-secondary)" }}>
                  {i === commitments.length - 1 ? "└─" : "├─"}
                </span>
                <span style={{ color: "var(--accent)" }}>
                  C{c.sequence_num}
                </span>
                <span>{truncateHash(c.commitment_hash)}</span>
              </div>
            ))}
          </div>
        )}
      </div>

      <PublishPanel />
    </div>
  );
}

function StatusItem({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <div className="flex justify-between items-center">
      <span className="text-sm" style={{ color: "var(--text-secondary)" }}>
        {label}
      </span>
      <span className="text-sm font-medium">{children}</span>
    </div>
  );
}
