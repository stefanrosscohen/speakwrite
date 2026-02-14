import type { ProofBundle } from "@speakwrite/core";

interface Props {
  bundle: ProofBundle;
}

function truncateHash(hash: string): string {
  return hash.slice(0, 12) + "...";
}

function formatTimestamp(ms: number): string {
  return new Date(ms).toLocaleTimeString();
}

export function ChainVisualization({ bundle }: Props) {
  return (
    <div className="mt-6">
      <h3
        className="text-sm font-semibold uppercase tracking-wider mb-3"
        style={{ color: "var(--text-secondary)" }}
      >
        Commitment Chain ({bundle.commitments.length} commitments,{" "}
        {bundle.total_keystroke_count.toLocaleString()} keystrokes)
      </h3>

      <div
        className="rounded-lg overflow-hidden"
        style={{
          background: "var(--bg-secondary)",
          border: "1px solid var(--border)",
        }}
      >
        {bundle.commitments.map((c, i) => {
          const isLast = i === bundle.commitments.length - 1;
          const isBinding = c.commitment_type === "content_binding";

          return (
            <div
              key={c.sequence_num}
              className="flex items-start gap-3 px-4 py-3"
              style={{
                borderBottom: isLast ? "none" : "1px solid var(--border)",
              }}
            >
              {/* Chain connector */}
              <div className="flex flex-col items-center flex-shrink-0 pt-1">
                <div
                  className="w-3 h-3 rounded-full"
                  style={{
                    background: isBinding ? "var(--accent)" : "var(--success)",
                  }}
                />
                {!isLast && (
                  <div
                    className="w-px flex-1 mt-1"
                    style={{
                      background: "var(--border)",
                      minHeight: "20px",
                    }}
                  />
                )}
              </div>

              {/* Content */}
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1">
                  <span
                    className="text-xs font-semibold"
                    style={{
                      color: isBinding ? "var(--accent)" : "var(--success)",
                    }}
                  >
                    {isBinding ? "CONTENT BINDING" : `C${c.sequence_num}`}
                  </span>
                  <span
                    className="text-xs"
                    style={{ color: "var(--text-secondary)" }}
                  >
                    {formatTimestamp(c.timestamp_ms)}
                  </span>
                </div>

                <div
                  className="font-mono text-xs truncate"
                  style={{ color: "var(--text-primary)" }}
                >
                  {truncateHash(c.commitment_hash)}
                </div>

                {c.previous_hash && (
                  <div
                    className="font-mono text-xs mt-0.5"
                    style={{ color: "var(--text-secondary)" }}
                  >
                    prev: {truncateHash(c.previous_hash)}
                  </div>
                )}

                {isBinding && c.content_hash && (
                  <div
                    className="font-mono text-xs mt-0.5"
                    style={{ color: "var(--text-secondary)" }}
                  >
                    content: {truncateHash(c.content_hash)}
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
