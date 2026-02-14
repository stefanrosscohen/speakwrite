import type {
  VerifyResult as VerifyResultType,
  DeviceAttestation,
} from "@speakwrite/core";

interface Props {
  result: VerifyResultType;
  deviceAttestation?: DeviceAttestation;
}

export function VerifyResult({ result, deviceAttestation }: Props) {
  const isValid = result.valid;

  return (
    <div
      className="mt-6 p-4 rounded-lg"
      style={{
        background: isValid
          ? "rgba(34, 197, 94, 0.08)"
          : "rgba(239, 68, 68, 0.08)",
        border: `1px solid ${isValid ? "rgba(34, 197, 94, 0.3)" : "rgba(239, 68, 68, 0.3)"}`,
      }}
    >
      <div className="flex items-center gap-2 mb-3">
        <span
          className="text-xl"
          style={{ color: isValid ? "var(--success)" : "var(--error)" }}
        >
          {isValid ? "\u2713" : "\u2717"}
        </span>
        <h2
          className="text-lg font-bold"
          style={{ color: isValid ? "var(--success)" : "var(--error)" }}
        >
          {isValid ? "Proof Valid" : "Proof Invalid"}
        </h2>
      </div>

      <p className="text-sm mb-4" style={{ color: "var(--text-secondary)" }}>
        {result.message}
      </p>

      <div className="grid grid-cols-2 gap-3 text-sm">
        <ResultItem
          label="Content Hash Match"
          value={result.content_hash_matches ? "Yes" : "No"}
          ok={result.content_hash_matches}
        />
        <ResultItem
          label="Chain Length"
          value={`${result.chain_length} commitments`}
          ok={result.chain_length > 0}
        />
        {result.binding_hash && (
          <ResultItem
            label="Binding Hash"
            value={result.binding_hash.slice(0, 16) + "..."}
            ok={true}
          />
        )}
        <ResultItem
          label="Content Hash"
          value={result.actual_content_hash.slice(0, 16) + "..."}
          ok={result.content_hash_matches}
        />
      </div>

      {/* Device Attestation Section */}
      {deviceAttestation && (
        <div className="mt-4 pt-4" style={{ borderTop: "1px solid var(--border)" }}>
          <h3
            className="text-xs font-semibold uppercase mb-3"
            style={{ color: "var(--text-secondary)", letterSpacing: "0.05em" }}
          >
            Device Attestation
          </h3>
          <div className="grid grid-cols-2 gap-3 text-sm">
            <ResultItem
              label="Platform"
              value={deviceAttestation.platform === "apple" ? "Apple (Secure Enclave)" : deviceAttestation.platform}
              ok={true}
            />
            <ResultItem
              label="Attestation Level"
              value={formatAttestationLevel(deviceAttestation.attestation_level)}
              ok={deviceAttestation.attestation_level === "platform_attested" || deviceAttestation.attestation_level === "hardware_verified"}
            />
            <ResultItem
              label="Biometric Gate"
              value={deviceAttestation.session_binding?.biometric_gate ? "Face ID / Touch ID" : "None"}
              ok={!!deviceAttestation.session_binding?.biometric_gate}
            />
            <ResultItem
              label="Signed Checkpoints"
              value={`${deviceAttestation.checkpoint_signatures.length} signatures`}
              ok={deviceAttestation.checkpoint_signatures.length > 0}
            />
            {deviceAttestation.attestation_certificate && (
              <ResultItem
                label="App Attest Certificate"
                value="Present (Apple-signed)"
                ok={true}
              />
            )}
            <ResultItem
              label="Device Public Key"
              value={deviceAttestation.device_public_key.slice(0, 16) + "..."}
              ok={true}
            />
          </div>
        </div>
      )}
    </div>
  );
}

function formatAttestationLevel(level: string): string {
  switch (level) {
    case "platform_attested":
      return "Platform Attested (L4)";
    case "hardware_verified":
      return "Hardware Verified (L3)";
    case "hardware_unverified":
      return "Hardware Unverified (L2)";
    case "software":
      return "Software (L1)";
    default:
      return "None (L0)";
  }
}

function ResultItem({
  label,
  value,
  ok,
}: {
  label: string;
  value: string;
  ok: boolean;
}) {
  return (
    <div
      className="p-2 rounded"
      style={{ background: "rgba(255, 255, 255, 0.03)" }}
    >
      <div
        className="text-xs mb-0.5"
        style={{ color: "var(--text-secondary)" }}
      >
        {label}
      </div>
      <div
        className="font-mono text-xs"
        style={{ color: ok ? "var(--success)" : "var(--error)" }}
      >
        {value}
      </div>
    </div>
  );
}
