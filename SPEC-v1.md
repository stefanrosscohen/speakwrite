# Speakwrite Protocol Specification

**Version:** 2.0-draft
**Status:** Working Draft
**Date:** 2026-02-16
**Authors:** Stefan Cohen

---

## 1. What This Is

Speakwrite is a native iOS app for writing and reading human-verified posts on the AT Protocol network. It is two things in one:

1. **A writing tool** that captures keystroke dynamics as you type, cryptographically signs each checkpoint with the iPhone's Secure Enclave, and publishes the proof alongside the post.

2. **A reader** that shows a global feed of all human-verified posts across the AT Protocol network — one place where everything was typed by a person.

**Scope:** Native SwiftUI iOS app. Short-form posts (up to ~5,000 chars). Published via AT Protocol (OAuth 2.0 with PKCE + DPoP). Verified via an open JSON proof bundle. Hardware attestation via Apple App Attest + Secure Enclave. Global verified feed for reading.

**What it proves:** A specific post was composed through physical typing on a genuine Apple device running the unmodified Speakwrite binary, with biometric authentication, incremental behavioral data committed at each checkpoint, and every commitment signed by a hardware-bound key.

**What it doesn't prove:** That the ideas are original, that no AI was consulted, or that the person didn't read something from another screen and retype it.

---

## 2. How It Works

### 2.1 The Three Layers

```
┌─────────────────────────────────────────────┐
│  Layer 3: Behavioral Analysis               │
│  Keystroke timing → human plausibility      │
├─────────────────────────────────────────────┤
│  Layer 2: Device Attestation                │
│  Apple App Attest + Secure Enclave          │
│  Biometric gate (Face ID / Touch ID)        │
├─────────────────────────────────────────────┤
│  Layer 1: Cryptographic Commitment Chain    │
│  SHA-256 hash chain → tamper-evident        │
│  Openable commitments → independently       │
│  verifiable behavioral data + content       │
└─────────────────────────────────────────────┘
```

**Layer 1** makes it tamper-evident and verifiable. Each checkpoint creates a SHA-256 commitment that includes the previous hash, behavioral features, and a document content snapshot — forming a chain. Every commitment is openable: the verifier can re-derive the hash from its components and confirm it matches. You can't edit the chain, swap the content, or fabricate behavioral data without breaking the derivation.

**Layer 2** makes it hardware-backed. The iPhone's Secure Enclave holds a P-256 signing key that never leaves the silicon. Apple's App Attest service certifies the key was generated on a real device running the unmodified app binary. Face ID gates every session. Every commitment is signed.

**Layer 3** makes it behaviorally credible. Human typing has distinct statistical properties: variable inter-key timing, characteristic digraph patterns, natural pause distributions, error-and-correct patterns. The protocol captures these via native iOS keyboard APIs (`pressesBegan`/`pressesEnded` for hardware keyboards, `insertText`/`deleteBackward` for the soft keyboard) and commits them into the proof chain.

### 2.2 Session Lifecycle

```
1. User selects Compose tab → Face ID triggered (biometric gate)
2. Secure Enclave key loaded with pre-authenticated LAContext
3. Session start signed: ECDSA("speakwrite:session:authorDid:sessionId|timestamp")
4. User types → CaptureTextView captures keystroke events
5. Every 60 seconds → Checkpoint:
   - Extract cumulative behavioral features from all keystrokes
   - Compute document hash: SHA-256(current_document_content)
   - Compute commitment hash: SHA-256(previous || nonce || features || document_hash)
   - Sign with Secure Enclave: ECDSA("speakwrite:checkpoint:sequenceNum|commitmentHash")
6. User hits "Publish" →
   - Final checkpoint with remaining keystrokes
   - Compute content hash: SHA-256(final_post_text)
   - Compute content binding: SHA-256(chain_tip || "CONTENT_BINDING" || content_hash)
   - Sign final binding: ECDSA("speakwrite:binding:contentHash|bindingHash")
   - Assemble proof bundle (JSON)
   - Publish post + proof to AT Protocol
```

### 2.3 The Proof Bundle

The proof bundle is a JSON object. This IS the protocol — anyone who can compute SHA-256 and verify ECDSA can verify it.

```json
{
  "version": "2.0.0",
  "document_id": "uuid",
  "content_hash": "hex-encoded SHA-256",
  "binding_hash": "hex-encoded SHA-256",
  "total_keystroke_count": 847,
  "created_at": "2026-02-14T12:00:00Z",

  "commitments": [
    {
      "sequence_num": 0,
      "commitment_hash": "hex...",
      "previous_hash": null,
      "nonce": "hex-encoded 32 bytes",
      "timestamp_ms": 1739530800000,
      "commitment_type": "behavioral",
      "content_hash": null,
      "features_json": "{\"typing_speed_cpm\":420,...}",
      "document_hash": "hex-encoded SHA-256 of document at checkpoint",
      "document_length": 312,
      "keystroke_count": 127
    },
    {
      "sequence_num": 1,
      "commitment_hash": "hex...",
      "previous_hash": "hex...",
      "nonce": "hex-encoded 32 bytes",
      "timestamp_ms": 1739530860000,
      "commitment_type": "behavioral",
      "content_hash": null,
      "features_json": "{\"typing_speed_cpm\":380,...}",
      "document_hash": "hex-encoded SHA-256 of document at checkpoint",
      "document_length": 647,
      "keystroke_count": 312
    },
    {
      "sequence_num": 2,
      "commitment_hash": "hex...",
      "previous_hash": "hex...",
      "nonce": "",
      "timestamp_ms": 1739530920000,
      "commitment_type": "content_binding",
      "content_hash": "hex-encoded SHA-256 of post text"
    }
  ],

  "device_attestation": {
    "platform": "apple",
    "attestation_type": "app_attest",
    "attestation_level": "platform_attested",
    "device_public_key": "base64-encoded P-256 public key (64 bytes: x||y from CryptoKit rawRepresentation)",
    "app_id": "io.speakwrite.app",
    "attestation_certificate": "base64-encoded App Attest certificate chain",
    "session_binding": {
      "session_id": "uuid",
      "biometric_gate": true,
      "session_start_signature": "base64(P-256 ECDSA over 'speakwrite:session:authorDid:sessionId|timestamp')",
      "session_start_timestamp": "2026-02-14T12:00:00Z",
      "author_did": "did:plc:abc123..."
    },
    "checkpoint_signatures": [
      {
        "sequence_num": 0,
        "commitment_hash": "hex...",
        "signature": "base64(P-256 ECDSA over 'speakwrite:checkpoint:sequenceNum|commitmentHash')"
      }
    ],
    "final_signature": "base64(P-256 ECDSA over 'speakwrite:binding:contentHash|bindingHash')"
  }
}
```

### 2.4 Field Reference

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Protocol version (semver). `"2.0.0"` for this spec. |
| `document_id` | string | UUID identifying this document |
| `content_hash` | string | SHA-256 hex digest of the final post text |
| `binding_hash` | string | SHA-256 hex digest binding chain to content |
| `total_keystroke_count` | number | Total keystroke events captured |
| `created_at` | string | ISO-8601 timestamp |
| `commitments` | array | Ordered chain of commitment objects |
| `device_attestation` | object | Platform attestation envelope (always present on iOS) |

**Commitment fields:**

| Field | Type | Description |
|-------|------|-------------|
| `sequence_num` | number | Position in chain (0-indexed) |
| `commitment_hash` | string | SHA-256 hex digest of this commitment |
| `previous_hash` | string \| null | Hash of previous commitment (null for first) |
| `nonce` | string | Hex-encoded 32-byte random nonce |
| `timestamp_ms` | number | Millisecond timestamp (`ProcessInfo.systemUptime * 1000`) |
| `commitment_type` | string | `"behavioral"` or `"content_binding"` |
| `content_hash` | string \| null | Only set for `content_binding` type |
| `features_json` | string | Raw Tier1 feature JSON (behavioral only). Openable: verifier re-derives commitment from this. |
| `document_hash` | string | SHA-256 hex of document content at checkpoint (behavioral only) |
| `document_length` | number | Character count of document at checkpoint |
| `keystroke_count` | number | Cumulative keystroke count at checkpoint |

**Device attestation fields:**

| Field | Type | Description |
|-------|------|-------------|
| `platform` | string | `"apple"` (only platform currently) |
| `attestation_type` | string | `"app_attest"` |
| `attestation_level` | string | `"platform_attested"` when App Attest succeeds; `"hardware_unverified"` when SE key exists but no Apple cert |
| `device_public_key` | string | Base64-encoded P-256 public key (64 bytes `x\|\|y` from CryptoKit; verifiers should also accept 65-byte uncompressed `0x04\|\|x\|\|y`) |
| `app_id` | string | Bundle identifier (`"io.speakwrite.app"`) |
| `attestation_certificate` | string | Base64-encoded App Attest certificate chain from Apple |
| `checkpoint_signatures` | array | ECDSA signatures over each checkpoint |
| `final_signature` | string | ECDSA signature over `"speakwrite:binding:content_hash\|binding_hash"` |

---

## 3. Cryptographic Operations

### 3.1 Primitives

| Primitive | Instantiation | Purpose |
|-----------|--------------|---------|
| Hash function **H** | SHA-256 | Content hashing, commitment derivation, challenge generation |
| Signature scheme **S** | ECDSA with P-256 (secp256r1), SHA-256 | Checkpoint signing, session binding, content binding |
| Nonce generation | 256-bit CSPRNG | Commitment freshness |
| Key storage | Apple Secure Enclave (SEP) | Private key never leaves hardware |
| Key attestation | Apple App Attest (`DCAppAttestService`) | Certifies key is on genuine device with unmodified binary |
| Biometric gate | `LAContext` with `.biometryCurrentSet` | Proves human presence at session start |

### 3.2 SHA-256 Content Hash

```
sha256Hex(content: string | Uint8Array) → hex string
```

Lowercase hex-encoded SHA-256 digest. Used for `content_hash` and `document_hash`.

### 3.3 Commitment Hash (v2)

```
commitmentHash(previous: hex | null, nonce: bytes[32], features: bytes, documentHash: hex) → hex string
```

Computes: `H(previous_bytes || nonce || features_bytes || document_hash_bytes)`

Where:
- `previous_bytes` = hex-decoded previous commitment hash (empty if null/first in chain)
- `nonce` = 32 raw random bytes
- `features_bytes` = UTF-8 encoded `features_json` string
- `document_hash_bytes` = hex-decoded SHA-256 of document content at checkpoint

This is a **transparent commitment**: all inputs are published in the proof bundle, so any verifier can re-derive the hash and confirm it matches. The nonce prevents a verifier from precomputing hashes for feature values they haven't seen — but once published, the commitment is fully openable.

**Note on concatenation:** The hash input is a raw byte concatenation of variable-length fields. Parsing is unambiguous because `previous_bytes` is either 0 or 32 bytes (null vs SHA-256 output), `nonce` is always exactly 32 bytes, and `document_hash_bytes` is always exactly 32 bytes — only `features_bytes` is variable-length, and it occupies the remaining bytes between the fixed-length fields. A future protocol version may adopt explicit length-prefixing for defense in depth.

### 3.4 Content Binding Hash

```
contentBindingHash(chainTip: hex, contentHash: hex) → hex string
```

Computes: `H(chain_tip_bytes || "CONTENT_BINDING" || content_hash_bytes)`

The UTF-8 literal `"CONTENT_BINDING"` is the domain separator. This binds the entire commitment chain to the final published content.

### 3.5 Nonce Generation

32 random bytes (256 bits) via `SecRandomCopyBytes` (iOS) or `crypto.getRandomValues()` (Web Crypto). Hex-encoded when stored in the proof bundle.

In v2, all commitment inputs are published — the nonce no longer hides anything. It serves one purpose: **Uniqueness** — two identical checkpoints produce different hashes, preventing hash collision without features changing. Note: the nonce does NOT provide temporal freshness. A random nonce proves uniqueness, not *when* the commitment was created. Temporal claims rest on the self-reported timestamps and the signed session start time. True freshness would require an interactive challenge from a verifier or a trusted timestamping authority, neither of which this protocol uses.

### 3.6 Signatures

P-256 ECDSA with SHA-256, computed inside the Secure Enclave via a biometric-gated key.

| Signature | Message format | When |
|-----------|---------------|------|
| Session start | `"speakwrite:session:authorDid:sessionId\|timestamp"` (UTF-8) | After Face ID, before first keystroke |
| Checkpoint | `"speakwrite:checkpoint:sequenceNum\|commitmentHash"` (UTF-8) | At each 60-second checkpoint |
| Final binding | `"speakwrite:binding:contentHash\|bindingHash"` (UTF-8) | At publish time |

Each signature message carries a domain prefix (`speakwrite:session:`, `speakwrite:checkpoint:`, `speakwrite:binding:`) to prevent cross-type confusion — a valid checkpoint signature cannot be reinterpreted as a session start signature, even if the payload bytes happened to collide.

The private key is generated with CryptoKit's `SecureEnclave.P256.Signing.PrivateKey` using:
- P-256 (secp256r1) curve, hardware-bound in the Secure Enclave
- Access control: `.biometryCurrentSet | .privateKeyUsage`
- `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`

The key persists in the Keychain across sessions. The same key signs all proofs from a device, enabling cross-proof consistency analysis.

---

## 4. Verification

Anyone can verify a proof bundle. No server, no API key, no trust required.

### 4.1 Steps

1. **Content hash.** Compute `H(post_content)`. Compare to `content_hash` in bundle. If mismatch: the content has been modified since publication.

2. **Chain integrity.** Walk the commitment chain. Each `commitment_hash` at position N must be referenced as `previous_hash` at position N+1.

3. **Commitment re-derivation.** For each behavioral commitment, re-derive the commitment hash from the published components:
   ```
   expected = H(hex_decode(previous_hash) || hex_decode(nonce) || utf8(features_json) || hex_decode(document_hash))
   assert expected == commitment_hash
   ```
   This confirms the behavioral data and document snapshot were not tampered with after the commitment was created. If any input was modified, the re-derived hash will not match.

4. **Document hash binding.** Verify the last behavioral commitment's `document_hash` equals the bundle's `content_hash`. This proves the final document content was committed into the chain before the content binding was computed — you can't type A and publish B.

5. **Content binding.** The final commitment (type `content_binding`) must satisfy:
   ```
   commitment_hash == H(hex_decode(previous_hash) || utf8("CONTENT_BINDING") || hex_decode(content_hash))
   ```

6. **Device attestation signature verification.**
   - Import `device_public_key` as a P-256 public key (uncompressed format, 65 bytes: `0x04 || x || y`). Note: CryptoKit exports 64 bytes (`x || y`); prepend `0x04` if the key is 64 bytes.
   - Verify `session_start_signature` against `"speakwrite:session:author_did:session_id|session_start_timestamp"` (include `author_did` when present; omit the DID prefix for pre-identity-binding bundles).
   - Verify each `checkpoint_signature` against `"speakwrite:checkpoint:sequence_num|commitment_hash"`.
   - Verify `final_signature` against `"speakwrite:binding:content_hash|binding_hash"`.
   - All signatures use ECDSA with SHA-256.
   - Verify `attestation_certificate` chains to Apple's App Attest Root CA (proves the public key is hardware-bound on a genuine Apple device running the unmodified app binary).
   - **Note:** All timestamps in the proof bundle are self-reported by the client device. A fabricator with a modified device could set arbitrary timestamps. Verifiers should treat timestamps as claims, not facts, and cross-reference with external evidence (e.g., AT Protocol record creation time) when available.

7. **Consistency checks (non-fatal warnings).**
   - `total_keystroke_count >= document_length * 0.5` (can't type 500 chars with 50 keys, even with autocorrect).
   - `keystroke_count` per commitment is monotonically non-decreasing.
   - `document_length` per commitment is generally non-decreasing (tolerance for deletions — flag if >50% of checkpoints show decrease).
   - Timestamps are monotonically increasing.
   - `typing_speed_cpm` in `features_json` is between 1 and 1000 CPM (human range).
   - Session duration plausibility: if total session time < 5 seconds and content length > 100 chars, flag as implausible.
   - Session start timestamp is not after `created_at` (would indicate fabricated timestamps).
   - Feature drift: if `typing_speed_cpm` changes by 3x or more between consecutive checkpoints, flag as dramatic shift (with cumulative features, a 3x change indicates a very large underlying behavioral change).

### 4.2 Reference Implementation

The `@speakwrite/core` TypeScript library provides:

```typescript
verifyProofBundle(bundle: ProofBundle, content: string): Promise<VerifyResult>
verifyChainIntegrity(commitments: ProofBundleCommitment[]): Promise<ChainIntegrityResult>
```

These use the Web Crypto API and run in any browser or Node.js environment.

`VerifyResult` includes:

| Field | Type | Description |
|-------|------|-------------|
| `valid` | boolean | Overall validity |
| `content_hash_matches` | boolean | Content matches proof |
| `chain_length` | number | Number of commitments |
| `signatures_valid` | boolean \| undefined | All ECDSA signatures verified (undefined if no attestation) |
| `key_attested` | boolean \| undefined | `true` only when certificate chain verified to Apple Root CA. `false` means signatures are internally consistent but key provenance is unverified. |
| `attestation_level` | string \| null | e.g. `"platform_attested"` |
| `signature_count` | number | Total signatures verified |
| `consistency_warnings` | string[] | Non-fatal plausibility warnings |

---

## 5. Security Analysis

### 5.1 Trust Assumptions

The protocol's security rests on three assumptions:

1. **SHA-256 is collision-resistant.** No efficient algorithm can find two distinct inputs with the same SHA-256 output. This is standard and widely accepted.

2. **ECDSA with P-256 is existentially unforgeable under chosen-message attack (EU-CMA).** An adversary who does not possess the Secure Enclave private key cannot forge a valid signature for any message, even after observing signatures on other messages.

3. **The Apple hardware trust chain is intact.** Specifically:
   - The Secure Enclave Processor (SEP) correctly isolates the private key.
   - App Attest correctly certifies that a key was generated on a genuine Apple device running the unmodified app binary.
   - A non-jailbroken device faithfully delivers iOS keyboard events through `UIPress` (physical) and `UITextInput` (soft keyboard) APIs.

If any of these assumptions is broken, the corresponding security property degrades. We state this explicitly rather than claiming unconditional security.

### 5.2 Security Properties

**Property 1 — Chain immutability.** Given collision resistance of H, an adversary cannot produce a valid commitment chain where any commitment's hash was computed over different inputs than the ones published in the bundle. Re-derivation (step 4.1.3) catches any modification.

**Property 2 — Content binding.** Given collision resistance of H, an adversary cannot produce a valid proof bundle where the published content differs from the content committed in the chain. The document hash at the last behavioral checkpoint must equal the bundle's content hash (step 4.1.4), and the content binding hash ties the chain tip to the content (step 4.1.5).

**Property 3 — Signature unforgeability.** Given EU-CMA security of ECDSA-P256, an adversary without access to the Secure Enclave private key cannot produce valid signatures for checkpoint commitments, session starts, or content bindings.

**Property 4 — Device authenticity.** Given the integrity of Apple's App Attest service, the `attestation_certificate` proves the signing key was generated inside a Secure Enclave on a genuine Apple device running the unmodified Speakwrite binary. This means the keystroke capture code (`CaptureTextView`) was not modified, and the commitment computation was performed by the real app.

**Property 5 — Human presence.** The biometric gate (Face ID / Touch ID) proves a registered biometric identity authenticated the session. The Secure Enclave key is created with `.biometryCurrentSet` access control — it cannot sign without a successful biometric evaluation. If the user's biometric enrollment changes (e.g., new face enrolled), the key is invalidated.

**Property 6 — Identity binding.** The session start signature includes the author's AT Protocol DID (`author_did`). This binds the proof to a specific identity — a valid proof bundle cannot be republished under a different account without invalidating the session start signature.

**Dependency note:** Properties 4 and 5 are conditional on successful verification of the `attestation_certificate` chain to Apple's Root CA (step 4.1.6). Without cert chain verification (`key_attested: false` in `VerifyResult`), an adversary can self-generate a P-256 keypair and produce a bundle that passes all other cryptographic checks. Properties 1, 2, 3, and 6 hold unconditionally — they depend only on SHA-256 collision resistance and ECDSA unforgeability, not on the hardware trust chain.

### 5.3 Attestation Coverage

The attestation chain from physical keypress to signed proof:

```
Physical key press
  │
  ├─ iOS delivers UIPress event (hardware keyboard)
  │  or UITextInput callback (soft keyboard)
  │         ↓
  │  CaptureTextView records KeystrokeEvent
  │  (this code is attested by App Attest — binary is unmodified)
  │         ↓
  │  Feature extraction computes behavioral statistics
  │         ↓
  │  Commitment hash binds features + document snapshot
  │         ↓
  │  Secure Enclave signs the commitment
  │  (key is hardware-bound, biometric-gated, Apple-attested)
  │         ↓
  └─ Proof bundle published
```

**What is attested:** The app binary (App Attest), the signing key origin (Secure Enclave), human presence (biometrics), and every commitment in the chain (ECDSA signatures).

**What is not independently attested:** The path from physical key press to iOS API callback. iOS does not provide a cryptographic attestation that a specific `UIPress` event originated from the physical keyboard hardware. On a non-jailbroken device with an attested binary, this gap is closed by OS integrity — the app receives events through standard iOS APIs that cannot be programmatically injected by other apps in the sandbox. On a jailbroken device, this assumption breaks.

### 5.4 Adversary Model

We consider four adversary classes with increasing capability:

| Adversary | Capabilities | What they can do | Defense |
|-----------|-------------|-----------------|---------|
| **Remote** | Can only interact with the published proof bundle | Verify, replay, or analyze proofs | Content binding prevents replay; chain re-derivation prevents forgery |
| **App-level** | Can run code alongside Speakwrite on a non-jailbroken device | Cannot inject keystrokes into another app's sandbox; cannot access SE key | iOS sandbox isolation; biometric-gated SE key |
| **Jailbroken device** | Full root access, can hook iOS frameworks | Can inject fake UIPress events, intercept callbacks | App Attest may detect jailbreak; behavioral analysis detects synthetic patterns; but SE key may be compromised |
| **Hardware** | Physical access, chip-level attacks | Can potentially extract SE keys | Out of scope; Apple's hardware security is the trust boundary |

### 5.5 What the Protocol Defends Against

| Attack | Defense | Strength |
|--------|---------|----------|
| Copy-paste AI text | Keystroke count will be zero or near-zero. Consistency check fails. | Strong |
| Modify content after signing | Content hash re-derivation fails. SHA-256 collision required. | Cryptographic |
| Tamper with behavioral data | Commitment re-derivation fails. SHA-256 collision required. | Cryptographic |
| Forge signatures without SE key | ECDSA unforgeability. P-256 discrete log required. | Cryptographic |
| Use a modified app binary | App Attest certificate will not verify against Apple Root CA. | Hardware-backed |
| Replay proof for different content | Content binding hash includes the specific content hash. | Cryptographic |
| Inject keystrokes from another app | iOS sandbox prevents cross-app input injection on non-jailbroken devices. | OS-enforced |
| Naive keystroke scripting | Behavioral features detect uniform timing, zero hold-time variance, impossible digraph patterns. | Statistical |
| Sophisticated timing simulation | High-dimensional feature space (flight time, hold time, digraphs, error patterns, overlap ratio). Cross-feature correlations are hard to simulate simultaneously. | Statistical |

### 5.6 What the Protocol Does Not Defend Against

| Attack | Why | Cost to attacker |
|--------|-----|-----------------|
| Human transcription of AI text | Real typing produces real behavioral patterns | Must type at human speed on a real device with Face ID |
| Jailbroken device with framework hooks | Can inject synthetic UIPress events that look real to the app | Requires jailbreak + custom hooks + behavioral model |
| Reading AI output and retyping | Indistinguishable from original composition once internalized | Real-time cost of retyping |

**Behavioral layer (Layer 3) limitations:** The behavioral layer collects evidence but does not make a binary classification. There is no decision boundary, no false-positive rate, no trained model. Behavioral features are committed into the proof for human or automated analysis, but the protocol itself does not declare a threshold for "human enough." This is intentional — behavioral analysis is evidence, not a verdict.

### 5.7 Honest Assessment

Speakwrite makes deception expensive. It does not make it impossible.

Verifying a post costs the reader nothing — SHA-256 and ECDSA verification. Faking a proof requires: a genuine Apple device, Face ID authentication, typing the content at human speed with plausible behavioral dynamics, and the unmodified app binary. This is categorically harder than prompting an LLM.

The protocol produces **forensic evidence**, not mathematical certainty. A single proof is weak evidence. A corpus of proofs from the same identity, exhibiting consistent behavioral patterns over time, is strong evidence. Trust builds progressively.

---

## 6. Device Attestation: Apple Implementation

### 6.1 Key Generation and Attestation

On first launch, the app generates two keys in the Secure Enclave:

1. **App Attest key** — Generated via `DCAppAttestService.generateKey()`. Apple's attestation service issues a certificate chain proving: (a) the key lives in a Secure Enclave, (b) on a genuine Apple device, (c) running the unmodified app binary identified by `app_id`. The attestation is a challenge-response: the app sends `H(keyId)` as the challenge, and Apple returns a signed attestation object.

2. **Session signing key** — A P-256 key generated with CryptoKit's `SecureEnclave.P256.Signing.PrivateKey` in the Secure Enclave, with access control flags requiring `.biometryCurrentSet`. This key can only sign when Face ID / Touch ID has been evaluated in the current `LAContext`. The key persists in the Keychain across app launches and is reused for all sessions.

### 6.2 Session Flow

1. **Face ID** is triggered once when the user selects the Compose tab (`LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)`).
2. The pre-authenticated `LAContext` is used to load the SE signing key (`SecKeyCreateSignature`).
3. **Session start** is signed: `ECDSA("speakwrite:session:authorDid:sessionId|timestamp")`. The author's AT Protocol DID is included to bind the proof to their identity.
4. All subsequent checkpoint signatures use the same pre-authenticated context — no additional Face ID prompts.
5. The **final binding** is signed: `ECDSA("speakwrite:binding:contentHash|bindingHash")`.
6. After proof export, the `LAContext` is invalidated. A new session requires new biometric authentication.

### 6.3 Why Native

Hardware attestation requires a native binary. A web app cannot provide equivalent guarantees because:
- App Attest certifies a specific app binary — there is no web equivalent.
- Secure Enclave signing requires native Keychain access with biometric access control.
- Any client can spoof web requests; browser-based "attestation" is meaningless without hardware backing.

The entire proof chain — from keystroke capture through Secure Enclave signing — happens inside the signed native binary. There is no JavaScript bridge or web wrapper.

---

## 7. Behavioral Capture

### 7.1 Keystroke Capture

A custom `CaptureTextView` (UITextView subclass) captures keystroke events through two parallel mechanisms:

**Hardware keyboard** (physical keys via UIPress API):
- `pressesBegan(_:with:)` — captures key-down with precise timing, modifier flags, and raw key code
- `pressesEnded(_:with:)` — captures key-up for hold time measurement

**Software keyboard** (virtual keyboard via UITextInput protocol):
- `insertText(_:)` — captures character insertion with synthetic key-down/key-up
- `deleteBackward()` — captures backspace

**IME composition** (for CJK and other input methods):
- `setMarkedText(_:selectedRange:)` — marks composing state
- `unmarkText()` — ends composition

All events are timestamped with `ProcessInfo.processInfo.systemUptime` (monotonic clock, sub-millisecond resolution).

### 7.2 Keystroke Event Structure

Each keystroke event contains:

| Field | Type | Description |
|-------|------|-------------|
| `event_type` | string | `"KeyDown"` or `"KeyUp"` |
| `key` | string | Key label (e.g. `"a"`, `"Enter"`, `" "`) |
| `code` | string | Key code (e.g. `"KeyA"`, physical keyboard raw code) |
| `timestamp` | number | Milliseconds since boot (monotonic) |
| `shift_key` | boolean | Shift modifier state |
| `ctrl_key` | boolean | Control modifier state |
| `alt_key` | boolean | Alt modifier state |
| `meta_key` | boolean | Command modifier state |
| `repeat` | boolean | Is key repeat |
| `is_composing` | boolean | Is composing (IME) |
| `sequence_number` | number | Monotonic event counter |

### 7.3 Feature Extraction

From raw events, we compute two tiers of features cumulatively (all keystrokes from session start to current checkpoint):

**Tier 1 — Biometric signature (timing):**
- Flight time (inter-key interval): mean, std, median
- Hold time (key-down to key-up): mean, std
- Digraph matrix: timing statistics for every observed character pair (count, mean, std, median, p10, p90)
- Overlap ratio: fraction of key presses where the next key is pressed before the previous is released (roll typing)
- Typing speed (chars/min)

**Tier 2 — Error patterns:**
- Backspace rate, delete rate
- Error burst count and mean burst length
- Immediate correction ratio (corrections within 2 keystrokes of error)
- Revision ratio (total corrections / total keystrokes)

### 7.4 Feature Vector Structure

Each behavioral commitment includes a feature vector as `features_json`:

```json
{
  "version": "1.0.0",
  "window_start_ms": 1739530800000,
  "window_end_ms": 1739530860000,
  "keystroke_count": 127,
  "tier1": {
    "flight_time_mean": 142.5,
    "flight_time_std": 67.3,
    "flight_time_median": 128.0,
    "hold_time_mean": 89.2,
    "hold_time_std": 31.4,
    "typing_speed_cpm": 420,
    "overlap_ratio": 0.12,
    "digraph_matrix": {
      "a→s": { "count": 5, "mean": 112.3, "std_dev": 23.1, "median": 108.0, "p10": 85.0, "p90": 140.0 }
    }
  },
  "tier2": {
    "backspace_rate": 0.08,
    "delete_rate": 0.01,
    "error_burst_count": 3,
    "mean_error_burst_length": 2.1,
    "immediate_correction_ratio": 0.72,
    "revision_ratio": 0.09
  }
}
```

---

## 8. Architecture

### 8.1 Project Structure

```
speakwrite/
├── packages/core/           @speakwrite/core — reference TypeScript library
│   └── src/
│       ├── types/           ProofBundle, KeystrokeEvent, FeatureVector types
│       ├── crypto/          SHA-256 hashing, commitment chain, content binding
│       ├── verification/    Bundle verification, chain integrity, signature verification
│       └── atproto/         Lexicon definitions, AT Protocol client helpers
│
├── apps/ios-native/         Native SwiftUI iOS app
│   └── Speakwrite/
│       ├── Crypto/          SHA-256, commitment hashing (CryptoKit)
│       ├── Models/          SwiftData models (Keystroke, Commitment, Document, Session)
│       ├── Features/        Tier 1 + Tier 2 feature extraction
│       ├── Services/        DeviceAttestation, ProofService, SessionService, ATProtoService
│       ├── Views/           SwiftUI views (Login, Editor, Feed, Timeline, Profile, Settings)
│       │   └── Components/  Shared components (PostRow, AvatarView, StatView)
│       └── ViewModels/      AppViewModel (@Observable)
│
├── apps/verifier/           Standalone web verification tool
├── apps/site/               Landing page (speakwrite.io)
└── SPEC-v1.md               This document
```

### 8.2 Data Flow

```
Physical key → iOS keyboard API → CaptureTextView → KeystrokeEvent
                                                          ↓
                                                   SwiftData (local)
                                                          ↓
                                               Feature Extraction (Tier1 + Tier2)
                                                          ↓
                                     SHA-256 Commitment (features + document hash, chained)
                                                          ↓
                                          Secure Enclave ECDSA Signature (P-256)
                                                          ↓
                                                   Proof Bundle (JSON)
                                                          ↓
                                     AT Protocol (OAuth + DPoP) → Published Post
```

### 8.3 Storage

All data is local-first. SwiftData stores keystroke events, commitment chain entries, feature vectors, and document metadata. Nothing leaves the device until the user explicitly publishes.

DPoP key pairs and OAuth tokens are stored in the iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` protection.

---

## 9. Distribution: AT Protocol

### 9.1 Why AT Protocol

- Open protocol — no platform lock-in.
- User-owned data — proofs live in the author's Personal Data Server (PDS).
- Federation — any PDS can host proofs, any client can verify them.

### 9.2 Authentication

OAuth 2.0 with PKCE + DPoP per the AT Protocol specification:

1. **Client metadata** is discoverable at `https://www.speakwrite.io/app/client-metadata.json`
2. **Pushed Authorization Request (PAR)** to the user's PDS authorization server
3. **ASWebAuthenticationSession** presents the AT Protocol login flow
4. **Token exchange** with DPoP-bound access tokens
5. **DPoP proofs** include `ath` (access token hash) per RFC 9449 §4.2

The redirect URI uses a private-use URI scheme: `io.speakwrite.www:/oauth/callback` (reversed FQDN of the client_id domain per AT Protocol requirements).

DPoP key pairs are persisted in the iOS Keychain for session restoration. The DPoP signing key is bound to the access token — a new key pair invalidates existing tokens.

### 9.3 Custom Lexicon

Proofs are stored as records in the author's AT Protocol repo under a custom collection:

**Collection:** `io.speakwrite.proof`

```json
{
  "$type": "io.speakwrite.proof",
  "contentHash": "hex-encoded SHA-256",
  "bindingHash": "hex-encoded SHA-256",
  "chainLength": 3,
  "totalKeystrokes": 847,
  "proofBundle": "{...JSON-stringified full proof bundle...}",
  "verifierUrl": "https://verify.speakwrite.io/...",
  "createdAt": "2026-02-14T12:00:00Z"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `contentHash` | string | yes | SHA-256 hex digest of post content |
| `bindingHash` | string | yes | Final binding hash |
| `chainLength` | number | yes | Count of commitments in chain |
| `totalKeystrokes` | number | yes | Total keystroke events |
| `proofBundle` | string | yes | JSON-stringified `ProofBundle` |
| `verifierUrl` | string | no | URL to verification page |
| `createdAt` | string | yes | ISO-8601 datetime |

### 9.4 Social Post

When publishing, the app creates two records:

1. **`app.bsky.feed.post`** — The post text, with `tags: ["speakwrite", "human-verified"]` on the record for discovery. The post text itself is clean with no footer.
2. **`io.speakwrite.proof`** — The full proof bundle stored in the author's repo

### 9.5 Verified Feed (Reader)

The app queries `app.bsky.feed.searchPosts` on `api.bsky.app` to discover human-verified posts. Detection uses:

1. **Tag search (primary):** `tag=speakwrite` — matches posts with the `speakwrite` tag on the record.
2. **Text search (backward compat):** Searches for legacy footer text to surface older posts that predate tag-based tagging.

Results are returned with `sort=latest` for reverse chronological ordering. Posts are displayed with author info, verification badges, and keystroke/commitment counts.

The feed supports two sub-feeds:

- **Following** — Human-verified posts from accounts the signed-in user follows.
- **For You** — All human-verified posts across the network (global discovery).

Public API read endpoints (timeline, verified feed, profiles, post threads) use unauthenticated requests because DPoP-bound tokens are PDS-specific and cannot be used against `api.bsky.app`.

---

## 10. Open Questions

1. **Behavioral baseline.** We extract features but don't yet compare them to a population baseline. Future work: a "human plausibility score" derived from population statistics.
2. **Progressive trust.** A single proof is weak evidence. A corpus of proofs from the same identity, exhibiting consistent behavioral patterns over time, is strong evidence. The protocol should support cross-proof consistency analysis.
3. **Cross-platform.** Android implementation would use hardware attestation (Play Integrity API) and TEE-backed keystore. The proof bundle format is platform-agnostic.
4. **App Attest certificate chain verification.** Full CBOR parsing of the App Attest attestation object and certificate chain verification to Apple's Root CA. Currently the verifier checks signatures against the public key but does not verify the key's provenance through the certificate chain. The `VerifyResult.key_attested` field is always `false` until this is implemented — `signatures_valid: true` + `key_attested: false` means "the math checks out but the key could be anyone's."

---

*This spec describes what's built. The protocol is the proof bundle JSON format — anyone can build a verifier or a compatible app. The security analysis describes the trust assumptions and their limits honestly.*
