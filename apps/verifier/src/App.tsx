import { useState, useEffect } from "react";
import { VerifyForm } from "./components/VerifyForm";
import { VerifyResult } from "./components/VerifyResult";
import { ChainVisualization } from "./components/ChainVisualization";
import type {
  ProofBundle,
  VerifyResult as VerifyResultType,
} from "@speakwrite/core";
import { verifyProofBundle } from "@speakwrite/core";

export default function App() {
  const [content, setContent] = useState("");
  const [bundleJson, setBundleJson] = useState("");
  const [result, setResult] = useState<VerifyResultType | null>(null);
  const [bundle, setBundle] = useState<ProofBundle | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [verifying, setVerifying] = useState(false);

  // Check URL params for pre-loaded bundle
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const bundleParam = params.get("bundle");
    if (bundleParam) {
      try {
        const parsed = JSON.parse(bundleParam);
        setBundleJson(JSON.stringify(parsed, null, 2));
      } catch {
        // Invalid bundle in URL — ignore
      }
    }

    const atUri = params.get("at");
    if (atUri) {
      loadFromATProto(atUri);
    }
  }, []);

  async function resolvePdsEndpoint(did: string): Promise<string> {
    if (did.startsWith("did:plc:")) {
      // Resolve via PLC directory
      const res = await fetch(`https://plc.directory/${encodeURIComponent(did)}`);
      if (!res.ok) throw new Error(`PLC directory lookup failed: ${res.status}`);
      const doc = await res.json();
      // Find the PDS service endpoint
      const pdsService = doc.service?.find(
        (s: { id: string; type: string; serviceEndpoint: string }) =>
          s.id === "#atproto_pds" || s.type === "AtprotoPersonalDataServer",
      );
      if (!pdsService?.serviceEndpoint) {
        throw new Error("No PDS endpoint found in DID document");
      }
      return pdsService.serviceEndpoint;
    }

    if (did.startsWith("did:web:")) {
      // Resolve via .well-known/did.json
      const domain = did.replace("did:web:", "").replace(/:/g, "/");
      const res = await fetch(`https://${domain}/.well-known/did.json`);
      if (!res.ok) throw new Error(`did:web lookup failed: ${res.status}`);
      const doc = await res.json();
      const pdsService = doc.service?.find(
        (s: { id: string; type: string; serviceEndpoint: string }) =>
          s.id === "#atproto_pds" || s.type === "AtprotoPersonalDataServer",
      );
      if (!pdsService?.serviceEndpoint) {
        throw new Error("No PDS endpoint found in DID document");
      }
      return pdsService.serviceEndpoint;
    }

    throw new Error(`Unsupported DID method: ${did}`);
  }

  async function loadFromATProto(atUri: string) {
    try {
      // Parse at:// URI: at://did/collection/rkey
      const parts = atUri.replace("at://", "").split("/");
      if (parts.length < 3) throw new Error("Invalid AT URI");

      const [did, collection, rkey] = parts;

      // Resolve the PDS endpoint from the DID
      const pdsEndpoint = await resolvePdsEndpoint(did);
      const recordUrl = `${pdsEndpoint}/xrpc/com.atproto.repo.getRecord?repo=${encodeURIComponent(did)}&collection=${encodeURIComponent(collection)}&rkey=${encodeURIComponent(rkey)}`;

      const res = await fetch(recordUrl);
      if (!res.ok) throw new Error(`Failed to fetch record: ${res.status}`);

      const data = await res.json();
      const record = data.value;

      if (record?.proofBundle) {
        const parsed =
          typeof record.proofBundle === "string"
            ? JSON.parse(record.proofBundle)
            : record.proofBundle;
        setBundleJson(JSON.stringify(parsed, null, 2));
      }
    } catch (e) {
      setError(`Failed to load from AT Protocol: ${e}`);
    }
  }

  async function handleVerify() {
    setError(null);
    setResult(null);
    setBundle(null);
    setVerifying(true);

    try {
      const parsed: ProofBundle = JSON.parse(bundleJson);
      setBundle(parsed);

      const verifyResult = await verifyProofBundle(parsed, content);
      setResult(verifyResult);
    } catch (e) {
      setError(e instanceof SyntaxError ? "Invalid JSON in proof bundle" : String(e));
    } finally {
      setVerifying(false);
    }
  }

  return (
    <div className="max-w-3xl mx-auto px-4 py-8">
      <header className="mb-8">
        <h1
          className="text-2xl font-bold mb-1"
          style={{ color: "var(--accent)" }}
        >
          Speakwrite Verifier
        </h1>
        <p className="text-sm" style={{ color: "var(--text-secondary)" }}>
          Verify human-authorship proofs. Runs entirely in your browser — no
          server, no trust required.
        </p>
      </header>

      <VerifyForm
        content={content}
        bundleJson={bundleJson}
        onContentChange={setContent}
        onBundleJsonChange={setBundleJson}
        onVerify={handleVerify}
        verifying={verifying}
      />

      {error && (
        <div
          className="mt-4 p-3 rounded-lg text-sm"
          style={{
            background: "rgba(239, 68, 68, 0.1)",
            color: "var(--error)",
            border: "1px solid rgba(239, 68, 68, 0.2)",
          }}
        >
          {error}
        </div>
      )}

      {result && (
        <VerifyResult
          result={result}
          deviceAttestation={bundle?.device_attestation}
        />
      )}

      {bundle && result?.valid && <ChainVisualization bundle={bundle} />}

      <footer
        className="mt-12 pt-4 border-t text-xs text-center"
        style={{
          borderColor: "var(--border)",
          color: "var(--text-secondary)",
        }}
      >
        Verification uses SHA-256. No data leaves your browser. Anyone can build
        a verifier — the proof bundle format is an open protocol.
      </footer>
    </div>
  );
}
