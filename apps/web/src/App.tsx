import { useEffect, useState } from "react";
import { Editor } from "./components/Editor";
import { initOAuth, onSessionDeleted, signIn, logout } from "./lib/services/atproto";
import { PostBar } from "./components/PostBar";
import { useAppStore } from "./stores/app-store";
import { isNativeShell } from "./lib/services/device-attestation";

/* ================================================================
   SPEAKWRITE — Cypherpunk Typewriter UI
   "Every keystroke was a confession."
   ================================================================ */

function RequiresIOSScreen() {
  return (
    <div
      className="flex flex-col items-center justify-center h-screen px-6 text-center"
      style={{ background: "var(--bg-primary)" }}
    >
      <div
        style={{
          fontFamily: "var(--font-mono)",
          fontSize: "11px",
          color: "var(--text-secondary)",
          maxWidth: "360px",
          lineHeight: "1.8",
        }}
      >
        <div
          style={{
            color: "var(--accent)",
            fontSize: "14px",
            fontWeight: 700,
            letterSpacing: "0.15em",
            textTransform: "uppercase",
            marginBottom: "24px",
          }}
        >
          [ACCESS DENIED]
        </div>
        <p style={{ marginBottom: "16px" }}>
          SPEAKWRITE v1 requires iOS for full human-authorship proofs &mdash;
          Face ID biometric gating, Secure Enclave signing, and Apple Device
          Attestation. These hardware guarantees are unavailable in a browser.
        </p>
        <div
          style={{
            marginTop: "24px",
            padding: "12px",
            border: "1px solid var(--border)",
            background: "var(--bg-surface)",
          }}
        >
          <span style={{ color: "var(--text-secondary)" }}>
            &gt; To <strong style={{ color: "var(--text-primary)" }}>verify</strong> a proof:{" "}
          </span>
          <a
            href="https://speakwrite.io/verify"
            style={{
              color: "var(--accent)",
              textDecoration: "none",
              borderBottom: "1px dashed var(--accent)",
            }}
          >
            speakwrite.io/verify
          </a>
        </div>
      </div>
    </div>
  );
}

function LoginScreen({ authError }: { authError?: string | null }) {
  const [handle, setHandle] = useState("");
  const [signingIn, setSigningIn] = useState(false);
  const [error, setError] = useState<string | null>(authError ?? null);

  const handleSignIn = async () => {
    if (!handle.trim()) return;
    setSigningIn(true);
    setError(null);
    try {
      await signIn(handle.trim());
      // Browser redirects away — this line won't execute
    } catch (e) {
      setSigningIn(false);
      setError(String(e));
    }
  };

  return (
    <div
      className="flex flex-col items-center justify-center h-screen px-8"
      style={{ background: "var(--bg-primary)" }}
    >
      <div className="w-full max-w-sm">
        {/* Title — brutalist, monospaced */}
        <div className="text-center mb-12">
          <h1
            style={{
              fontFamily: "var(--font-mono)",
              fontSize: "28px",
              fontWeight: 700,
              letterSpacing: "0.2em",
              textTransform: "uppercase",
              color: "var(--accent)",
              marginBottom: "16px",
              textShadow: "0 0 20px rgba(0, 255, 65, 0.3)",
            }}
          >
            Speakwrite
          </h1>
          <div
            style={{
              width: "60px",
              height: "1px",
              background: "var(--accent)",
              margin: "0 auto 16px",
              opacity: 0.5,
            }}
          />
          <p
            style={{
              fontFamily: "var(--font-mono)",
              fontSize: "11px",
              lineHeight: "1.8",
              color: "var(--text-secondary)",
              maxWidth: "280px",
              margin: "0 auto",
            }}
          >
            Every keystroke cryptographically committed.
            Every word device-attested. Every proof published.
          </p>
        </div>

        {/* Sign in form — terminal style */}
        <div className="flex flex-col gap-3">
          <div
            style={{
              fontFamily: "var(--font-mono)",
              fontSize: "10px",
              textTransform: "uppercase",
              letterSpacing: "0.1em",
              color: "var(--text-secondary)",
              marginBottom: "4px",
            }}
          >
            &gt; identify
          </div>
          <input
            type="text"
            placeholder="handle.bsky.social"
            value={handle}
            onChange={(e) => setHandle(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") handleSignIn();
            }}
            autoCapitalize="none"
            autoCorrect="off"
            spellCheck={false}
            style={{
              width: "100%",
              padding: "12px 16px",
              fontFamily: "var(--font-mono)",
              fontSize: "14px",
              background: "var(--bg-surface)",
              color: "var(--text-primary)",
              border: "1px solid var(--border)",
              borderRadius: "0",
              outline: "none",
              caretColor: "var(--accent)",
              boxSizing: "border-box",
            }}
          />
          <button
            onClick={handleSignIn}
            disabled={signingIn || !handle.trim()}
            style={{
              width: "100%",
              padding: "12px",
              fontFamily: "var(--font-mono)",
              fontSize: "12px",
              fontWeight: 600,
              letterSpacing: "0.1em",
              textTransform: "uppercase",
              background: signingIn || !handle.trim() ? "var(--bg-surface)" : "var(--accent)",
              color: signingIn || !handle.trim() ? "var(--text-secondary)" : "var(--bg-primary)",
              border: signingIn || !handle.trim()
                ? "1px solid var(--border)"
                : "1px solid var(--accent)",
              borderRadius: "0",
              cursor: signingIn || !handle.trim() ? "default" : "pointer",
              transition: "all 0.15s",
            }}
          >
            {signingIn ? "[ AUTHENTICATING... ]" : "[ SIGN IN ]"}
          </button>
        </div>

        {error && (
          <div
            style={{
              marginTop: "16px",
              padding: "12px",
              fontFamily: "var(--font-mono)",
              fontSize: "11px",
              color: "var(--danger)",
              background: "rgba(255, 51, 51, 0.08)",
              border: "1px solid rgba(255, 51, 51, 0.2)",
              lineHeight: "1.6",
            }}
          >
            ERROR: {error}
          </div>
        )}

        <p
          style={{
            fontFamily: "var(--font-mono)",
            fontSize: "10px",
            textAlign: "center",
            marginTop: "32px",
            lineHeight: "1.8",
            color: "#444",
          }}
        >
          Authenticate via AT Protocol.
          Your proofs are published to your PDS.
        </p>
      </div>
    </div>
  );
}

function LoadingScreen() {
  return (
    <div
      className="flex flex-col items-center justify-center h-screen"
      style={{ background: "var(--bg-primary)" }}
    >
      <div
        style={{
          fontFamily: "var(--font-mono)",
          fontSize: "14px",
          fontWeight: 700,
          letterSpacing: "0.2em",
          textTransform: "uppercase",
          color: "var(--accent)",
          marginBottom: "16px",
          textShadow: "0 0 20px rgba(0, 255, 65, 0.3)",
        }}
      >
        Speakwrite
      </div>
      <div
        style={{
          fontFamily: "var(--font-mono)",
          fontSize: "11px",
          color: "var(--text-secondary)",
          animation: "blink 1s infinite",
        }}
      >
        initializing_
      </div>
    </div>
  );
}

export default function App() {
  const setATProto = useAppStore((s) => s.setATProto);
  const setATProtoLoading = useAppStore((s) => s.setATProtoLoading);
  const clearATProto = useAppStore((s) => s.clearATProto);
  const atprotoHandle = useAppStore((s) => s.atprotoHandle);
  const atprotoLoading = useAppStore((s) => s.atprotoLoading);
  const [authError, setAuthError] = useState<string | null>(null);

  useEffect(() => {
    let cleanup: (() => void) | undefined;

    async function init() {
      try {
        const result = await initOAuth();
        if (result) {
          setATProto(result.handle, result.did);
        }
      } catch (e) {
        console.error("OAuth init failed:", e);
        setAuthError(String(e));
      } finally {
        setATProtoLoading(false);
      }
    }

    init();

    cleanup = onSessionDeleted(() => {
      clearATProto();
    });

    return () => {
      cleanup?.();
    };
  }, [setATProto, setATProtoLoading, clearATProto]);

  // v1: Writing requires the iOS native shell for full device attestation
  // Temporarily disabled for testing — re-enable for production
  // if (!isNativeShell()) {
  //   return <RequiresIOSScreen />;
  // }

  // Still checking for existing OAuth session
  if (atprotoLoading) {
    return <LoadingScreen />;
  }

  // Not logged in — show login
  if (!atprotoHandle) {
    return <LoginScreen authError={authError} />;
  }

  // Logged in — editor with post bar
  return (
    <div className="flex flex-col h-screen" style={{ background: "var(--bg-primary)" }}>
      {/* Header — minimal terminal bar */}
      <header
        className="flex items-center justify-between px-4 py-2 flex-shrink-0"
        style={{
          borderBottom: "1px solid var(--border)",
          background: "var(--bg-secondary)",
        }}
      >
        <span
          style={{
            fontFamily: "var(--font-mono)",
            fontSize: "11px",
            fontWeight: 600,
            letterSpacing: "0.15em",
            textTransform: "uppercase",
            color: "var(--accent)",
          }}
        >
          speakwrite
        </span>
        <button
          onClick={async () => {
            await logout();
            clearATProto();
          }}
          style={{
            fontFamily: "var(--font-mono)",
            fontSize: "10px",
            color: "var(--text-secondary)",
            background: "none",
            border: "none",
            cursor: "pointer",
            letterSpacing: "0.03em",
          }}
        >
          @{atprotoHandle}
        </button>
      </header>

      {/* Editor — full screen, scrollable */}
      <div className="flex-1 overflow-y-auto">
        <Editor />
      </div>

      {/* Post bar — sticky at bottom */}
      <PostBar />
    </div>
  );
}
