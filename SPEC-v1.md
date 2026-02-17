# Speakwrite Protocol Specification

**Version:** 3.0-draft
**Status:** Working Draft
**Date:** 2026-02-16
**Authors:** Stefan Cohen

---

## 1. What This Is

Speakwrite is a native iOS app for writing and reading human-verified posts on the AT Protocol network. It is two things in one:

1. **A writing tool** that enforces input restrictions (soft keyboard only, no paste, no dictation, no autocorrect), cryptographically signs each checkpoint with the iPhone's Secure Enclave, and publishes the proof alongside the post.

2. **A reader** that shows a global feed of all human-verified posts across the AT Protocol network — one place where everything was typed by a person.

**Scope:** Native SwiftUI iOS app. Short-form posts (up to ~5,000 chars). Published via AT Protocol (OAuth 2.0 with PKCE + DPoP). Verified via an open JSON proof bundle. Hardware attestation via Apple App Attest + Secure Enclave. Global verified feed for reading.

**What it proves:** A specific post was composed through restricted soft-keyboard input on a genuine Apple device running the unmodified Speakwrite binary, with biometric authentication, input restrictions (no paste, no dictation, no autocorrect, no hardware keyboard) enforced by the attested binary, and every commitment signed by a hardware-bound key.

**What it doesn't prove:** That the ideas are original, that no AI was consulted, or that the person didn't read something from another screen and retype it.

---

## 2. How It Works

### 2.1 The Three Layers

```
┌─────────────────────────────────────────────┐
│  Layer 3: Input Restriction                 │
│  Attested app restricts input to soft       │
│  keyboard only: no paste, no dictation,     │
│  no autocorrect, no hardware keyboard.      │
│  The restriction IS the guarantee.          │
├─────────────────────────────────────────────┤
│  Layer 2: Device Attestation                │
│  Apple App Attest + Secure Enclave          │
│  Biometric gate (Face ID / Touch ID)        │
├─────────────────────────────────────────────┤
│  Layer 1: Cryptographic Commitment Chain    │
│  SHA-256 hash chain → tamper-evident        │
│  Openable commitments → independently       │
│  verifiable content snapshots               │
└─────────────────────────────────────────────┘
```

**Layer 1** makes it tamper-evident and verifiable. Each checkpoint creates a SHA-256 commitment that includes the previous hash, a nonce, and a document content snapshot — forming a chain. Every commitment is openable: the verifier can re-derive the hash from its components and confirm it matches. You can't edit the chain or swap the content without breaking the derivation.

**Layer 2** makes it hardware-backed. The iPhone's Secure Enclave holds a P-256 signing key that never leaves the silicon. Apple's App Attest service certifies the key was generated on a real device running the unmodified app binary. Face ID gates every session. Every commitment is signed.

**Layer 3** makes it input-restricted. The attested app binary enforces that all input comes through the soft keyboard only. Paste is blocked (`canPerformAction` override), dictation is rejected (multi-character `insertText` filtered), autocorrect and predictive text are disabled (all `UITextSmartType` properties set to `.no`), and hardware keyboard events are consumed (`pressesBegan` intercepted). Because the binary is attested by App Attest, verifiers know these restrictions were enforced — the restriction itself is the guarantee, not statistical analysis of behavior.

### 2.2 Session Lifecycle

```
1. User selects Compose tab → Face ID triggered (biometric gate)
2. Secure Enclave key loaded with pre-authenticated LAContext
3. Session start signed: ECDSA("speakwrite:session:authorDid:sessionId|timestamp")
4. User types → InputRestrictedTextView enforces soft-keyboard-only input
5. Every 60 seconds → Checkpoint:
   - Compute document hash: SHA-256(current_document_content)
   - Compute commitment hash: SHA-256(previous || nonce || empty_data || document_hash)
   - Sign with Secure Enclave: ECDSA("speakwrite:checkpoint:sequenceNum|commitmentHash")
6. User hits "Publish" →
   - Final checkpoint
   - Compute content hash: SHA-256(final_post_text)
   - Compute content binding: SHA-256(chain_tip || "CONTENT_BINDING" || content_hash)
   - Sign final binding: ECDSA("speakwrite:binding:contentHash|bindingHash")
   - Assemble proof bundle (JSON) with input_restrictions attestation
   - Publish post + proof to AT Protocol
```

### 2.3 The Proof Bundle

The proof bundle is a JSON object. This IS the protocol — anyone who can compute SHA-256 and verify ECDSA can verify it.

```json
{
  "version": "3.0.0",
  "document_id": "uuid",
  "content_hash": "hex-encoded SHA-256",
  "binding_hash": "hex-encoded SHA-256",
  "total_keystroke_count": 847,
  "created_at": "2026-02-14T12:00:00Z",

  "input_restrictions": {
    "soft_keyboard_only": true,
    "paste_blocked": true,
    "dictation_blocked": true,
    "autocorrect_disabled": true,
    "spell_check_disabled": true,
    "predictive_disabled": true,
    "violation_count": 0
  },

  "commitments": [
    {
      "sequence_num": 0,
      "commitment_hash": "hex...",
      "previous_hash": null,
      "nonce": "hex-encoded 32 bytes",
      "timestamp_ms": 1739530800000,
      "commitment_type": "input_restricted",
      "content_hash": null,
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
      "commitment_type": "input_restricted",
      "content_hash": null,
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
| `version` | string | Protocol version (semver). `"3.0.0"` for this spec. |
| `document_id` | string | UUID identifying this document |
| `content_hash` | string | SHA-256 hex digest of the final post text |
| `binding_hash` | string | SHA-256 hex digest binding chain to content |
| `total_keystroke_count` | number | Total keystroke events captured |
| `created_at` | string | ISO-8601 timestamp |
| `input_restrictions` | object | Input restriction attestation (see below) |
| `commitments` | array | Ordered chain of commitment objects |
| `device_attestation` | object | Platform attestation envelope (always present on iOS) |

**Input restriction fields:**

| Field | Type | Description |
|-------|------|-------------|
| `soft_keyboard_only` | boolean | Only soft keyboard input accepted |
| `paste_blocked` | boolean | Paste action was blocked |
| `dictation_blocked` | boolean | Dictation input was rejected |
| `autocorrect_disabled` | boolean | Autocorrect was disabled |
| `spell_check_disabled` | boolean | Spell check was disabled |
| `predictive_disabled` | boolean | Predictive text was disabled |
| `violation_count` | number | Number of blocked input restriction violations during session |

**Commitment fields:**

| Field | Type | Description |
|-------|------|-------------|
| `sequence_num` | number | Position in chain (0-indexed) |
| `commitment_hash` | string | SHA-256 hex digest of this commitment |
| `previous_hash` | string \| null | Hash of previous commitment (null for first) |
| `nonce` | string | Hex-encoded 32-byte random nonce |
| `timestamp_ms` | number | Millisecond timestamp (`ProcessInfo.systemUptime * 1000`) |
| `commitment_type` | string | `"input_restricted"` or `"content_binding"` |
| `content_hash` | string \| null | Only set for `content_binding` type |
| `features_json` | string \| undefined | **v2 backward compatibility only.** Not present in v3 bundles. In v2, contained the raw Tier1 feature JSON. Verifiers should accept bundles with or without this field. |
| `document_hash` | string | SHA-256 hex of document content at checkpoint (`input_restricted` only) |
| `document_length` | number | Character count of document at checkpoint |
| `keystroke_count` | number | Cumulative keystroke count at checkpoint |

**v2 backward compatibility note:** Verifiers should accept bundles with `version: "2.0.0"` and `commitment_type: "behavioral"`. These bundles include `features_json` in each behavioral commitment and use `features_bytes` (UTF-8 encoded `features_json`) in the commitment hash derivation. v3 bundles use empty data (zero bytes) in place of `features_bytes`.

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

### 3.3 Commitment Hash (v3)

```
commitmentHash(previous: hex | null, nonce: bytes[32], data: bytes, documentHash: hex) → hex string
```

Computes: `H(previous_bytes || nonce || data || document_hash_bytes)`

Where:
- `previous_bytes` = hex-decoded previous commitment hash (empty if null/first in chain)
- `nonce` = 32 raw random bytes
- `data` = in v3, empty (zero bytes). In v2, this was the UTF-8 encoded `features_json` string.
- `document_hash_bytes` = hex-decoded SHA-256 of document content at checkpoint

This is a **transparent commitment**: all inputs are published in the proof bundle, so any verifier can re-derive the hash and confirm it matches. In v3, `data` is empty because the protocol no longer embeds behavioral features into the commitment — the guarantee comes from input restrictions enforced by the attested binary, not from committed feature vectors. The nonce ensures uniqueness: two checkpoints with the same document content produce different hashes.

**Note on concatenation:** The hash input is a raw byte concatenation of fixed-length fields. In v3, all fields are fixed-length: `previous_bytes` is either 0 or 32 bytes (null vs SHA-256 output), `nonce` is always exactly 32 bytes, `data` is always 0 bytes, and `document_hash_bytes` is always exactly 32 bytes. In v2, `data` (the `features_bytes`) was variable-length and occupied the remaining bytes between the fixed-length fields.

**v2 backward compatibility:** Verifiers processing v2 bundles should use `utf8(features_json)` as the `data` parameter. Verifiers processing v3 bundles should use empty data (zero bytes).

### 3.4 Content Binding Hash

```
contentBindingHash(chainTip: hex, contentHash: hex) → hex string
```

Computes: `H(chain_tip_bytes || "CONTENT_BINDING" || content_hash_bytes)`

The UTF-8 literal `"CONTENT_BINDING"` is the domain separator. This binds the entire commitment chain to the final published content.

### 3.5 Nonce Generation

32 random bytes (256 bits) via `SecRandomCopyBytes` (iOS) or `crypto.getRandomValues()` (Web Crypto). Hex-encoded when stored in the proof bundle.

All commitment inputs are published — the nonce does not hide anything. It serves one purpose: **Uniqueness** — two identical checkpoints produce different hashes, preventing hash collision without the document changing. Note: the nonce does NOT provide temporal freshness. A random nonce proves uniqueness, not *when* the commitment was created. Temporal claims rest on the self-reported timestamps and the signed session start time. True freshness would require an interactive challenge from a verifier or a trusted timestamping authority, neither of which this protocol uses.

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

3. **Commitment re-derivation.** For each `input_restricted` commitment, re-derive the commitment hash from the published components:
   ```
   # v3 (input_restricted commitments): data is empty
   expected = H(hex_decode(previous_hash) || hex_decode(nonce) || hex_decode(document_hash))

   # v2 backward compat (behavioral commitments): data is features_json
   expected = H(hex_decode(previous_hash) || hex_decode(nonce) || utf8(features_json) || hex_decode(document_hash))

   assert expected == commitment_hash
   ```
   This confirms the document snapshot was not tampered with after the commitment was created. If any input was modified, the re-derived hash will not match.

4. **Document hash binding.** Verify the last `input_restricted` (or `behavioral` in v2) commitment's `document_hash` equals the bundle's `content_hash`. This proves the final document content was committed into the chain before the content binding was computed — you can't type A and publish B.

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
   - `total_keystroke_count >= document_length * 0.5` (can't type 500 chars with 50 keys).
   - `keystroke_count` per commitment is monotonically non-decreasing.
   - `document_length` per commitment is generally non-decreasing (tolerance for deletions — flag if >50% of checkpoints show decrease).
   - Timestamps are monotonically increasing.
   - Session duration plausibility: if total session time < 5 seconds and content length > 100 chars, flag as implausible.
   - Session start timestamp is not after `created_at` (would indicate fabricated timestamps).
   - **Input restrictions validation (v3):** Verify `input_restrictions` is present and all restriction fields are `true`. If `violation_count > 0`, flag as warning — violations indicate attempted restricted input that was blocked. A high violation count may indicate adversarial probing.
   - **v2 backward compat:** For v2 bundles with `features_json`, the typing speed and feature drift checks from v2 still apply.

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
   - A non-jailbroken device faithfully delivers iOS soft keyboard events through the `UITextInput` API, and input restriction enforcement in the attested binary cannot be bypassed without modifying the binary.

If any of these assumptions is broken, the corresponding security property degrades. We state this explicitly rather than claiming unconditional security.

### 5.2 Security Properties

**Property 1 — Chain immutability.** Given collision resistance of H, an adversary cannot produce a valid commitment chain where any commitment's hash was computed over different inputs than the ones published in the bundle. Re-derivation (step 4.1.3) catches any modification.

**Property 2 — Content binding.** Given collision resistance of H, an adversary cannot produce a valid proof bundle where the published content differs from the content committed in the chain. The document hash at the last `input_restricted` checkpoint must equal the bundle's content hash (step 4.1.4), and the content binding hash ties the chain tip to the content (step 4.1.5).

**Property 3 — Signature unforgeability.** Given EU-CMA security of ECDSA-P256, an adversary without access to the Secure Enclave private key cannot produce valid signatures for checkpoint commitments, session starts, or content bindings.

**Property 4 — Device authenticity.** Given the integrity of Apple's App Attest service, the `attestation_certificate` proves the signing key was generated inside a Secure Enclave on a genuine Apple device running the unmodified Speakwrite binary. This means the input restriction enforcement code (`InputRestrictedTextView`) was not modified, and the commitment computation was performed by the real app.

**Property 5 — Human presence.** The biometric gate (Face ID / Touch ID) proves a registered biometric identity authenticated the session. The Secure Enclave key is created with `.biometryCurrentSet` access control — it cannot sign without a successful biometric evaluation. If the user's biometric enrollment changes (e.g., new face enrolled), the key is invalidated.

**Property 6 — Identity binding.** The session start signature includes the author's AT Protocol DID (`author_did`). This binds the proof to a specific identity — a valid proof bundle cannot be republished under a different account without invalidating the session start signature.

**Dependency note:** Properties 4 and 5 are conditional on successful verification of the `attestation_certificate` chain to Apple's Root CA (step 4.1.6). Without cert chain verification (`key_attested: false` in `VerifyResult`), an adversary can self-generate a P-256 keypair and produce a bundle that passes all other cryptographic checks. Properties 1, 2, 3, and 6 hold unconditionally — they depend only on SHA-256 collision resistance and ECDSA unforgeability, not on the hardware trust chain.

### 5.3 Attestation Coverage

The attestation chain from soft-keyboard input to signed proof:

```
Soft keyboard tap
  │
  ├─ iOS delivers UITextInput callback (insertText / deleteBackward)
  │         ↓
  │  InputRestrictedTextView enforces input restrictions
  │  (paste blocked, dictation rejected, autocorrect disabled,
  │   hardware keyboard consumed — this code is attested by App Attest)
  │         ↓
  │  Commitment hash binds document snapshot
  │         ↓
  │  Secure Enclave signs the commitment
  │  (key is hardware-bound, biometric-gated, Apple-attested)
  │         ↓
  └─ Proof bundle published with input_restrictions attestation
```

**What is attested:** The app binary (App Attest), the signing key origin (Secure Enclave), human presence (biometrics), input restriction enforcement (attested binary), and every commitment in the chain (ECDSA signatures).

**What is not independently attested:** The path from physical screen tap to iOS API callback. iOS does not provide a cryptographic attestation that a specific `UITextInput` callback originated from a physical touch on the soft keyboard. On a non-jailbroken device with an attested binary, this gap is closed by OS integrity — the app receives events through standard iOS APIs that cannot be programmatically injected by other apps in the sandbox. On a jailbroken device, this assumption breaks.

### 5.4 Adversary Model

We consider four adversary classes with increasing capability:

| Adversary | Capabilities | What they can do | Defense |
|-----------|-------------|-----------------|---------|
| **Remote** | Can only interact with the published proof bundle | Verify, replay, or analyze proofs | Content binding prevents replay; chain re-derivation prevents forgery |
| **App-level** | Can run code alongside Speakwrite on a non-jailbroken device | Cannot inject keystrokes into another app's sandbox; cannot access SE key | iOS sandbox isolation; biometric-gated SE key |
| **Jailbroken device** | Full root access, can hook iOS frameworks | Can inject fake UITextInput callbacks, bypass input restrictions at the OS level | App Attest may detect jailbreak; input restrictions are enforced by the attested binary (cannot be bypassed without modifying the binary, which invalidates attestation); but SE key may be compromised |
| **Hardware** | Physical access, chip-level attacks | Can potentially extract SE keys | Out of scope; Apple's hardware security is the trust boundary |

### 5.5 What the Protocol Defends Against

| Attack | Defense | Strength |
|--------|---------|----------|
| Copy-paste AI text | Paste is blocked by `canPerformAction` override in `InputRestrictedTextView`. Attested binary enforces this. | Binary-attested |
| Dictation of AI text | Dictation input is rejected — multi-character `insertText` calls are filtered. Attested binary enforces this. | Binary-attested |
| Autocorrect injection | Autocorrect, spell check, and predictive text are disabled via `UITextSmartType` properties. Attested binary enforces this. | Binary-attested |
| Hardware keyboard input | `pressesBegan` events are consumed (not forwarded). Only soft keyboard input is accepted. Attested binary enforces this. | Binary-attested |
| Modify content after signing | Content hash re-derivation fails. SHA-256 collision required. | Cryptographic |
| Tamper with commitment data | Commitment re-derivation fails. SHA-256 collision required. | Cryptographic |
| Forge signatures without SE key | ECDSA unforgeability. P-256 discrete log required. | Cryptographic |
| Use a modified app binary | App Attest certificate will not verify against Apple Root CA. | Hardware-backed |
| Replay proof for different content | Content binding hash includes the specific content hash. | Cryptographic |
| Inject input from another app | iOS sandbox prevents cross-app input injection on non-jailbroken devices. | OS-enforced |

### 5.6 What the Protocol Does Not Defend Against

| Attack | Why | Cost to attacker |
|--------|-----|-----------------|
| Human transcription of AI text | Real typing on the soft keyboard satisfies all input restrictions | Must type at human speed on a real device with Face ID |
| Jailbroken device with framework hooks | Can bypass input restrictions at the OS level by hooking UITextInput | Requires jailbreak + custom hooks; App Attest may detect jailbreak |
| Reading AI output and retyping | Indistinguishable from original composition once internalized | Real-time cost of retyping on soft keyboard |

### 5.7 Honest Assessment

Speakwrite makes deception expensive. It does not make it impossible.

Verifying a post costs the reader nothing — SHA-256 and ECDSA verification. Faking a proof requires: a genuine Apple device, Face ID authentication, typing the content character-by-character on the soft keyboard, and the unmodified app binary. This is categorically harder than prompting an LLM.

The protocol produces **structural evidence**, not mathematical certainty. The input restrictions guarantee that the content was entered through the soft keyboard on an attested device — there is no shortcut through paste, dictation, or autocorrect. Trust comes from the attestation chain, not from statistical analysis.

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

The entire proof chain — from input restriction enforcement through Secure Enclave signing — happens inside the signed native binary. There is no JavaScript bridge or web wrapper.

---

## 7. Input Restriction

### 7.1 InputRestrictedTextView

A custom `InputRestrictedTextView` (UITextView subclass) enforces input restrictions that guarantee all content was entered through the soft keyboard, one character at a time. The restriction is the guarantee — rather than analyzing behavioral patterns after the fact, the attested binary prevents non-keyboard input from entering the document at all.

### 7.2 Restriction Table

| Restriction | Mechanism | iOS API | Effect |
|-------------|-----------|---------|--------|
| No paste | `canPerformAction(_:withSender:)` returns `false` for `paste:`, `cut:`, `select:`, `selectAll:` | `UIResponder` | Paste menu item never appears; programmatic paste is blocked |
| No dictation | `insertText(_:)` rejects calls where `text.count > 1` and the input is not an IME composition | `UITextInput` | Dictation delivers multi-character strings; single-character soft keyboard input passes through |
| No autocorrect | `autocorrectionType = .no`, `spellCheckingType = .no`, `smartQuotesType = .no`, `smartDashesType = .no`, `smartInsertDeleteType = .no` | `UITextInputTraits` | All automatic text transformation is disabled |
| No predictive text | `inlinePredictionType = .no` (iOS 17+) | `UITextInputTraits` | Predictive text bar does not appear |
| No hardware keyboard | `pressesBegan(_:with:)` consumes all key events (does not call `super`) | `UIResponder` | Physical keyboard input is silently dropped |

### 7.3 IME Handling (CJK)

CJK input methods (Chinese, Japanese, Korean) use a composition workflow where the user types phonetic characters that are converted to ideographs:

- `setMarkedText(_:selectedRange:)` — marks the composing region (e.g., pinyin input "ni" before selecting the character)
- `unmarkText()` — ends composition and commits the selected character

IME composition is explicitly allowed. The dictation filter distinguishes IME input from dictation input by tracking the `markedTextRange` state: if text is being composed (marked text is present), multi-character insertions are permitted. Dictation does not use the marked text workflow, so its multi-character insertions are rejected.

### 7.4 Violation Counting

Each blocked input attempt increments a violation counter. The final `violation_count` is included in the proof bundle's `input_restrictions` object. A non-zero violation count indicates that the user (or an automated tool) attempted restricted input that was blocked. Verifiers can use this as a signal:

- `violation_count == 0` — no restricted input was attempted
- `violation_count > 0` — restricted input was attempted and blocked; the content is still valid (the input never entered the document) but the attempt is recorded

---

## 8. Architecture

### 8.1 Project Structure

```
speakwrite/
├── packages/core/           @speakwrite/core — reference TypeScript library
│   └── src/
│       ├── types/           ProofBundle, InputRestrictions types
│       ├── crypto/          SHA-256 hashing, commitment chain, content binding
│       ├── verification/    Bundle verification, chain integrity, signature verification
│       └── atproto/         Lexicon definitions, AT Protocol client helpers
│
├── apps/ios-native/         Native SwiftUI iOS app
│   └── Speakwrite/
│       ├── Crypto/          SHA-256, commitment hashing (CryptoKit)
│       ├── Models/          SwiftData models (Commitment, Document, Session)
│       ├── Services/        DeviceAttestation, ProofService, SessionService, ATProtoService
│       ├── Views/           SwiftUI views (Login, Editor, Feed, Timeline, Profile, Settings)
│       │   └── Components/  Shared components (PostRow, AvatarView, StatView)
│       │                    InputRestrictedTextView (input restriction enforcement)
│       └── ViewModels/      AppViewModel (@Observable)
│
├── apps/verifier/           Standalone web verification tool
├── apps/site/               Landing page (speakwrite.io)
└── SPEC-v1.md               This document
```

### 8.2 Data Flow

```
Soft keyboard tap → iOS UITextInput API → InputRestrictedTextView
                                              │
                                              ├─ Input Restriction Enforcement
                                              │  (paste blocked, dictation rejected,
                                              │   autocorrect disabled, hardware KB consumed)
                                              │
                                              ↓
                                       SwiftData (local)
                                              ↓
                                SHA-256 Commitment (document hash, chained)
                                              ↓
                                Secure Enclave ECDSA Signature (P-256)
                                              ↓
                          Proof Bundle (JSON) + input_restrictions
                                              ↓
                        AT Protocol (OAuth + DPoP) → Published Post
```

### 8.3 Storage

All data is local-first. SwiftData stores commitment chain entries, document metadata, and input restriction state. Nothing leaves the device until the user explicitly publishes.

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

1. **Input restriction evolution.** Future iOS versions may introduce new input methods that bypass current restrictions. The restriction table (Section 7.2) must be updated as new input vectors emerge.
2. **Progressive trust.** A single proof is evidence that the content was typed on the soft keyboard. A corpus of proofs from the same identity builds confidence in the author's consistent use of the protocol.
3. **Cross-platform.** Android implementation would use hardware attestation (Play Integrity API) and TEE-backed keystore. The proof bundle format is platform-agnostic.
4. **App Attest certificate chain verification.** Full CBOR parsing of the App Attest attestation object and certificate chain verification to Apple's Root CA. Currently the verifier checks signatures against the public key but does not verify the key's provenance through the certificate chain. The `VerifyResult.key_attested` field is always `false` until this is implemented — `signatures_valid: true` + `key_attested: false` means "the math checks out but the key could be anyone's."

---

*This spec describes what's built. The protocol is the proof bundle JSON format — anyone can build a verifier or a compatible app. The security analysis describes the trust assumptions and their limits honestly. v3 replaces behavioral analysis with input restriction enforcement: the attested binary guarantees how content was entered, not what patterns it exhibited.*
