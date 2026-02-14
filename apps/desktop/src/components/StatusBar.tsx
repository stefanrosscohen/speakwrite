import { useAppStore } from "../stores/app-store";

function formatDuration(ms: number): string {
  const totalSeconds = Math.floor(ms / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}:${seconds.toString().padStart(2, "0")}`;
}

export function StatusBar() {
  const wordCount = useAppStore((s) => s.wordCount);
  const paragraphCount = useAppStore((s) => s.paragraphCount);
  const sessionDurationMs = useAppStore((s) => s.sessionDurationMs);

  return (
    <div
      className="flex items-center justify-between px-4 py-1.5 text-xs border-t"
      style={{
        borderColor: "var(--border)",
        background: "var(--bg-secondary)",
        color: "var(--text-secondary)",
      }}
    >
      <div className="flex gap-4">
        <span>Words: {wordCount.toLocaleString()}</span>
        <span>Paragraphs: {paragraphCount}</span>
      </div>
      <div>
        <span>Session: {formatDuration(sessionDurationMs)}</span>
      </div>
    </div>
  );
}
