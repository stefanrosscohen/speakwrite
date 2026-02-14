import { useEffect, useState } from "react";
import { Editor } from "./components/Editor";
import { initOAuth, onSessionDeleted, signIn, logout } from "./lib/services/atproto";
import { PostBar } from "./components/PostBar";
import { useAppStore } from "./stores/app-store";
import { isNativeShell } from "./lib/services/device-attestation";

function RequiresIOSScreen() {
  return (
    <div
      className="flex flex-col items-center justify-center h-screen px-6 text-center"
      style={{ background: "var(--bg-primary)" }}
    >
      <div className="text-5xl mb-6" role="img" aria-label="iPhone">
        &#x1F4F1;
      </div>
      <h1
        className="text-2xl font-bold mb-3"
        style={{ color: "var(--text-primary)" }}
      >
        Speakwrite requires iPhone
      </h1>
      <p
        className="text-sm max-w-md mb-6 leading-relaxed"
        style={{ color: "var(--text-secondary)" }}
      >
        Speakwrite v1 runs exclusively on iOS to provide full human-authorship
        proofs — including Face ID biometric gating, Secure Enclave signing,
        and Apple Device Attestation. These hardware guarantees aren't available
        in a browser.
      </p>
      <div
        className="text-xs px-4 py-2 rounded-lg"
        style={{
          background: "var(--bg-secondary)",
          color: "var(--text-secondary)",
          border: "1px solid var(--border)",
        }}
      >
        Looking to <strong>verify</strong> a proof? The{" "}
        <a
          href="https://speakwrite.io/verify"
          style={{ color: "var(--accent)", textDecoration: "underline" }}
        >
          verifier
        </a>{" "}
        works in any browser.
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
        {/* Logo / Title */}
        <div className="text-center mb-10">
          <h1
            className="text-3xl font-bold mb-2"
            style={{ color: "var(--accent)" }}
          >
            Speakwrite
          </h1>
          <p
            className="text-sm leading-relaxed"
            style={{ color: "var(--text-secondary)" }}
          >
            Write with proof. Every keystroke is cryptographically committed,
            device-attested, and published to the AT Protocol.
          </p>
        </div>

        {/* Sign in form */}
        <div className="flex flex-col gap-3">
          <input
            type="text"
            placeholder="yourname.bsky.social"
            value={handle}
            onChange={(e) => setHandle(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") handleSignIn();
            }}
            autoCapitalize="none"
            autoCorrect="off"
            spellCheck={false}
            className="w-full px-4 py-3 rounded-xl text-base outline-none"
            style={{
              background: "var(--bg-secondary)",
              color: "var(--text-primary)",
              border: "1px solid var(--border)",
            }}
          />
          <button
            onClick={handleSignIn}
            disabled={signingIn || !handle.trim()}
            className="w-full py-3 rounded-xl text-base font-semibold transition-opacity"
            style={{
              background: "var(--accent)",
              color: "#fff",
              border: "none",
              opacity: signingIn || !handle.trim() ? 0.5 : 1,
              cursor: signingIn || !handle.trim() ? "default" : "pointer",
            }}
          >
            {signingIn ? "Signing in..." : "Sign in with Bluesky"}
          </button>
        </div>

        {error && (
          <div
            className="mt-4 p-3 rounded-lg text-sm text-center"
            style={{
              background: "rgba(239, 68, 68, 0.1)",
              color: "#ef4444",
            }}
          >
            {error}
          </div>
        )}

        <p
          className="text-xs text-center mt-8 leading-relaxed"
          style={{ color: "var(--text-secondary)" }}
        >
          Sign in with your AT Protocol handle to start writing.
          Your proofs will be published to your PDS.
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
      <h1
        className="text-2xl font-bold mb-3"
        style={{ color: "var(--accent)" }}
      >
        Speakwrite
      </h1>
      <p className="text-sm" style={{ color: "var(--text-secondary)" }}>
        Loading...
      </p>
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
      {/* Header */}
      <header
        className="flex items-center justify-between px-4 py-3 flex-shrink-0"
        style={{
          borderBottom: "1px solid var(--border)",
          background: "var(--bg-secondary)",
        }}
      >
        <span className="text-sm font-semibold" style={{ color: "var(--accent)" }}>
          Speakwrite
        </span>
        <button
          onClick={async () => {
            await logout();
            clearATProto();
          }}
          className="text-xs"
          style={{
            color: "var(--text-secondary)",
            background: "none",
            border: "none",
            cursor: "pointer",
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
