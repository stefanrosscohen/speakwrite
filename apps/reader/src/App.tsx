import { useState } from "react";
import { Header } from "./components/Header";
import { SearchBar } from "./components/SearchBar";
import { FeedView } from "./components/FeedView";

/* ================================================================
   SPEAKWRITE READER — Verified Human Content Only
   ================================================================ */

export default function App() {
  const [authorHandle, setAuthorHandle] = useState<string | null>(null);

  return (
    <div className="flex flex-col min-h-screen" style={{ background: "var(--bg-primary)" }}>
      <Header />
      <SearchBar
        onSearch={setAuthorHandle}
        onClear={() => setAuthorHandle(null)}
        activeHandle={authorHandle}
      />

      {/* Feed */}
      <div className="flex-1">
        <FeedView authorHandle={authorHandle} />
      </div>

      {/* Footer */}
      <footer
        className="px-4 py-4 text-center"
        style={{
          borderTop: "1px solid var(--border)",
          fontFamily: "var(--font-mono)",
          fontSize: "10px",
          color: "#444",
          lineHeight: "1.8",
        }}
      >
        Showing only posts with Speakwrite human-authorship proofs.
        <br />
        Verification uses SHA-256. No data leaves your browser.
      </footer>
    </div>
  );
}
