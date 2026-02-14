/**
 * Device Attestation bridge.
 *
 * When running inside the Capacitor iOS shell, this calls through to the
 * native Swift plugin (App Attest + Secure Enclave).
 *
 * When running in a regular browser, all methods return null / no-op,
 * and `isAvailable()` returns false. The proof bundle simply omits the
 * `device_attestation` field.
 */

export interface AttestationSupport {
  appAttest: boolean;
  secureEnclave: boolean;
  platform: string;
}

export interface SessionStart {
  sessionId: string;
  timestamp: string;
  signature: string;
  biometricGate: boolean;
}

export interface CheckpointSignature {
  sequenceNum: number;
  commitmentHash: string;
  signature: string;
}

export interface FinalSignature {
  contentHash: string;
  bindingHash: string;
  signature: string;
}

export interface AttestationEnvelope {
  platform: string;
  attestationType: string;
  attestationLevel: string;
  devicePublicKey: string;
  appId: string;
  attestationCertificate?: string;
  sessionBinding?: {
    sessionId: string;
    biometricGate: boolean;
    sessionStartSignature?: string;
  };
  checkpointSignatures: CheckpointSignature[];
}

// Capacitor's registerPlugin is only available inside the native shell.
// We access it via the global Capacitor object to avoid bundling issues in browser-only builds.
let plugin: any = null;

function getPlugin() {
  if (plugin) return plugin;
  try {
    const cap = (window as any).Capacitor;
    if (!cap?.registerPlugin) return null;
    plugin = cap.registerPlugin("DeviceAttestation");
    return plugin;
  } catch {
    return null;
  }
}

/**
 * Returns true if running inside the Capacitor iOS shell with attestation support.
 */
export function isNativeShell(): boolean {
  return !!(window as any).Capacitor?.isNativePlatform?.();
}

/**
 * Check if device attestation is available.
 */
export async function isAvailable(): Promise<AttestationSupport | null> {
  if (!isNativeShell()) return null;
  const p = getPlugin();
  if (!p) return null;
  try {
    return await p.isSupported();
  } catch {
    return null;
  }
}

/**
 * Initialize device attestation (one-time). Generates App Attest key +
 * Secure Enclave signing key. Returns the public key.
 */
export async function initializeAttestation(): Promise<{
  keyId: string;
  publicKey: string;
} | null> {
  if (!isNativeShell()) return null;
  const p = getPlugin();
  if (!p) return null;
  return p.initialize();
}

/**
 * Start an attested session. Triggers biometric authentication (Face ID / Touch ID).
 */
export async function startAttestedSession(): Promise<SessionStart | null> {
  if (!isNativeShell()) return null;
  const p = getPlugin();
  if (!p) return null;
  return p.startSession();
}

/**
 * Sign a commitment checkpoint with the Secure Enclave key.
 */
export async function signCheckpoint(
  commitmentHash: string,
  sequenceNum: number,
): Promise<CheckpointSignature | null> {
  if (!isNativeShell()) return null;
  const p = getPlugin();
  if (!p) return null;
  return p.signCheckpoint({ commitmentHash, sequenceNum });
}

/**
 * Sign the final content binding with the Secure Enclave key.
 */
export async function signFinalBinding(
  contentHash: string,
  bindingHash: string,
): Promise<FinalSignature | null> {
  if (!isNativeShell()) return null;
  const p = getPlugin();
  if (!p) return null;
  return p.signFinal({ contentHash, bindingHash });
}

/**
 * Get the full attestation envelope for inclusion in the proof bundle.
 */
export async function getAttestationEnvelope(): Promise<AttestationEnvelope | null> {
  if (!isNativeShell()) return null;
  const p = getPlugin();
  if (!p) return null;
  return p.getAttestationEnvelope();
}
