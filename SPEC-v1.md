# Speakwrite v1 Specification

**Version:** 1.0-draft
**Status:** Working Draft
**Date:** 2026-02-14
**Authors:** Stefan Cohen

---

## 1. What This Is

Speakwrite is a native iOS app for writing and reading human-verified posts on the AT Protocol network. It is two things in one:

1. **A writing tool** that captures keystroke dynamics as you type, cryptographically signs each checkpoint with the iPhone's Secure Enclave, and publishes the proof alongside the post.

2. **A reader** that shows a global feed of all human-verified posts across the AT Protocol network — one place where everything was typed by a person.

**Scope of v1:** Native SwiftUI iOS app. Short-form posts (up to ~5,000 chars). Published via AT Protocol (OAuth 2.0 with PKCE + DPoP). Verified via an open JSON proof bundle. Hardware attestation via Apple App Attest + Secure Enclave. Global verified feed for reading.

**What it proves:** A specific post was composed through physical typing on a genuine Apple device, with keystroke behavior consistent with human motor patterns.

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
└─────────────────────────────────────────────┘
```

**Layer 1** makes it tamper-evident. Each checkpoint during writing creates a hash that includes the previous hash, forming a chain. You can't edit the chain after the fact without breaking it.

**Layer 2** makes it hardware-backed. The iPhone's Secure Enclave holds a signing key that never leaves the silicon. Apple's App Attest service certifies the key was generated on a real device running the unmodified app. Biometrics gate every session.

**Layer 3** makes it behaviorally credible. Human typing has distinct statistical properties: variable inter-key timing, characteristic digraph patterns, natural pause distributions, error-and-correct patterns. The protocol captures these and includes them in the proof.

### 2.2 Session Lifecycle

```
1. User opens app → signs in with AT Protocol handle (AT Protocol OAuth)
2. User starts typing → CaptureTextView captures keystroke events
3. Periodically → Checkpoint:
   - Extract behavioral features from keystrokes
   - Compute commitment hash (chained to previous)
   - Sign commitment with Secure Enclave key
4. User hits "Publish" →
   - Compute content hash: SHA-256(post_text)
   - Compute content binding: SHA-256(chain_tip || "CONTENT_BINDING" || content_hash)
   - Sign final binding with Secure Enclave key
   - Assemble proof bundle (JSON)
   - Publish post + proof to AT Protocol
```

### 2.3 The Proof Bundle

The proof bundle is a JSON object. This IS the protocol — anyone who can compute SHA-256 can verify it.

```json
{
  "version": "1.0.0",
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
      "content_hash": null
    },
    {
      "sequence_num": 1,
      "commitment_hash": "hex...",
      "previous_hash": "hex...",
      "nonce": "hex-encoded 32 bytes",
      "timestamp_ms": 1739530860000,
      "commitment_type": "behavioral",
      "content_hash": null
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
    "device_public_key": "base64-encoded P-256 public key",
    "app_id": "io.speakwrite.app",
    "attestation_certificate": "base64...",
    "session_binding": {
      "session_id": "uuid",
      "biometric_gate": true,
      "session_start_signature": "base64...",
      "session_start_timestamp": "2026-02-14T12:00:00Z"
    },
    "checkpoint_signatures": [
      {
        "sequence_num": 0,
        "commitment_hash": "hex...",
        "signature": "base64(P-256 ECDSA)"
      }
    ],
    "final_signature": "base64(P-256 ECDSA over content_hash|binding_hash)"
  }
}
```

### 2.4 Field Reference

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Protocol version (semver) |
| `document_id` | string | UUID identifying this document |
| `content_hash` | string | SHA-256 hex digest of the final post text |
| `binding_hash` | string | SHA-256 hex digest binding chain to content |
| `total_keystroke_count` | number | Total keystroke events captured |
| `created_at` | string | ISO-8601 timestamp |
| `commitments` | array | Ordered chain of commitment objects |
| `device_attestation` | object | Optional platform attestation envelope |

**Commitment fields:**

| Field | Type | Description |
|-------|------|-------------|
| `sequence_num` | number | Position in chain (0-indexed) |
| `commitment_hash` | string | SHA-256 hex digest of this commitment |
| `previous_hash` | string \| null | Hash of previous commitment (null for first) |
| `nonce` | string | Hex-encoded 32-byte random nonce |
| `timestamp_ms` | number | Millisecond timestamp |
| `commitment_type` | string | `"behavioral"` or `"content_binding"` |
| `content_hash` | string \| null | Only set for `content_binding` type |

**Device attestation fields:**

| Field | Type | Description |
|-------|------|-------------|
| `platform` | string | `"apple"`, `"android"`, or `"web"` |
| `attestation_type` | string | e.g. `"app_attest"` |
| `attestation_level` | string | `"none"` \| `"software"` \| `"hardware_unverified"` \| `"hardware_verified"` \| `"platform_attested"` |
| `device_public_key` | string | Base64-encoded public key for signature verification |
| `app_id` | string | Bundle identifier (e.g. `"io.speakwrite.app"`) |
| `checkpoint_signatures` | array | Signed commitment checksums |
| `final_signature` | string | Signature over `content_hash\|binding_hash` |

Every proof from Speakwrite includes `device_attestation` because the entire app is native iOS. There is no web fallback.

---

## 3. Cryptographic Operations

### 3.1 SHA-256 Content Hash

```
sha256Hex(content: string | Uint8Array) → hex string
```

Lowercase hex-encoded SHA-256 digest. Used for `content_hash`.

### 3.2 Commitment Hash

```
commitmentHash(previous: string | null, nonce: Uint8Array, data: Uint8Array) → hex string
```

Computes: `SHA-256(previous_bytes || nonce || data)`

Where `previous_bytes` is the hex-decoded previous hash (or empty if null).

### 3.3 Content Binding Hash

```
contentBindingHash(chainTip: string, contentHash: string) → hex string
```

Computes: `SHA-256(chain_tip_bytes || "CONTENT_BINDING" || content_hash_bytes)`

The UTF-8 literal `"CONTENT_BINDING"` is the domain separator. This binds the entire commitment chain to the final content.

### 3.4 Nonce Generation

32 random bytes (256 bits) via `crypto.getRandomValues()` (Web Crypto) or `SecRandomCopyBytes` (iOS). Hex-encoded when stored.

### 3.5 Signatures

P-256 ECDSA signatures via the iPhone's Secure Enclave. Each checkpoint signature covers `sequence_num|commitment_hash`. The final signature covers `content_hash|binding_hash`.

---

## 4. Verification

Anyone can verify a proof bundle. No server, no API key, no trust required.

### 4.1 Steps

1. **Content hash:** Compute `SHA-256(post_content)`. Compare to `content_hash` in bundle.

2. **Chain integrity:** Walk the commitment chain. Each `commitment_hash` at position N must reference the hash at position N-1 as its `previous_hash`. Timestamps must be monotonically increasing.

3. **Content binding:** The final commitment (type `content_binding`) must satisfy:
   ```
   commitment_hash == SHA-256(previous_hash_bytes || "CONTENT_BINDING" || content_hash_bytes)
   ```

4. **Device attestation:**
   - Verify the `attestation_certificate` chains to Apple's App Attest Root CA.
   - Verify each `checkpoint_signature` against the public key and corresponding `commitment_hash`.
   - Verify the `final_signature` against the public key and `content_hash|binding_hash`.

5. **Behavioral plausibility (optional):** Check that `total_keystroke_count` is plausible for the content length.

### 4.2 Reference Implementation

The `@speakwrite/core` TypeScript library provides:

```typescript
verifyProofBundle(bundle: ProofBundle, content: string): Promise<VerifyResult>
verifyChainIntegrity(commitments: ProofBundleCommitment[]): Promise<ChainIntegrityResult>
```

These use the Web Crypto API and can run in any browser or Node.js environment.

---

## 5. Distribution: AT Protocol

### 5.1 Why AT Protocol

- Open protocol — no platform lock-in.
- User-owned data — proofs live in the author's Personal Data Server (PDS).
- Federation — any PDS can host proofs, any client can verify them.

### 5.2 Authentication

OAuth 2.0 with PKCE + DPoP per the AT Protocol specification:

1. **Client metadata** is discoverable at `https://www.speakwrite.io/app/client-metadata.json`
2. **Pushed Authorization Request (PAR)** to the user's PDS authorization server
3. **ASWebAuthenticationSession** presents the AT Protocol login flow
4. **Token exchange** with DPoP-bound access tokens
5. **DPoP proofs** include `ath` (access token hash) per RFC 9449 §4.2

The redirect URI uses a private-use URI scheme: `io.speakwrite.www:/oauth/callback` (reversed FQDN of the client_id domain per AT Protocol requirements).

DPoP key pairs are persisted in the iOS Keychain for session restoration. The DPoP signing key is bound to the access token — a new key pair invalidates existing tokens.

### 5.3 Custom Lexicon

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

### 5.4 Social Post

When publishing, the app creates two records:

1. **`app.bsky.feed.post`** — The post text, with `tags: ["speakwrite", "human-verified"]` on the record for discovery. The post text itself is clean with no footer.
2. **`io.speakwrite.proof`** — The full proof bundle stored in the author's repo

### 5.5 Verified Feed (Reader)

The app queries `app.bsky.feed.searchPosts` on `api.bsky.app` to discover human-verified posts. Detection uses:

1. **Tag search (primary):** `tag=speakwrite` — matches posts with the `speakwrite` tag on the record.
2. **Text search (backward compat):** Searches for legacy footer text to surface older posts that predate tag-based tagging.

Results are returned with `sort=latest` for reverse chronological ordering. Posts are displayed with author info, verification badges, and keystroke/commitment counts.

The feed supports two sub-feeds:

- **Following** — Human-verified posts from accounts the signed-in user follows.
- **For You** — All human-verified posts across the network (global discovery).

Public API read endpoints (timeline, verified feed, profiles, post threads) use unauthenticated requests because DPoP-bound tokens are PDS-specific and cannot be used against `api.bsky.app`.

---

## 6. Device Attestation: Apple Implementation

### 6.1 How It Works

On first launch, the app generates two keys in the Secure Enclave:

1. **App Attest key** — Apple's attestation service issues a certificate chain proving the key is on a real device running the unmodified app.
2. **Session signing key** — A biometric-gated P-256 key that can only sign when Face ID / Touch ID confirms the user.

Every checkpoint and the final content binding are signed with the biometric-gated key. The signature covers `sequence_num|commitment_hash` for checkpoints and `content_hash|binding_hash` for the final binding.

### 6.2 Why Native

Hardware attestation requires a native binary. A web app cannot do this because:
- App Attest certifies a specific app binary — there is no web equivalent.
- Secure Enclave signing requires native keychain access.
- Any client can spoof web requests, making browser-based attestation meaningless.

The entire proof chain — from keystroke capture through Secure Enclave signing — happens inside the native binary. There is no JavaScript bridge or web wrapper.

### 6.3 Limitations

- **Jailbroken devices** may circumvent Secure Enclave protections.
- **No keyboard attestation.** iOS does not let the system keyboard sign its own output. The gap between "physical key press" and "signed data" is bridged by behavioral analysis, not cryptography.

---

## 7. Behavioral Capture

### 7.1 What We Capture

A custom `CaptureTextView` (UITextView subclass) captures keystroke events natively:

| Event | Data | Purpose |
|-------|------|---------|
| `insertText` / `pressesBegan` | key, code, timestamp, modifiers | Raw keystroke timing |
| `deleteBackward` / `pressesEnded` | key, code, timestamp | Hold time / correction tracking |
| `setMarkedText` / `unmarkText` | — | IME composition tracking |

Timestamps use `ProcessInfo.processInfo.systemUptime` for sub-millisecond resolution.

### 7.2 Keystroke Event Structure

Each keystroke event contains:

| Field | Type | Description |
|-------|------|-------------|
| `event_type` | string | `"KeyDown"` or `"KeyUp"` |
| `key` | string | Key label (e.g. `"a"`, `"Enter"`, `" "`) |
| `code` | string | DOM code (e.g. `"KeyA"`) |
| `timestamp` | number | Milliseconds since epoch |
| `shift_key` | boolean | Shift modifier state |
| `ctrl_key` | boolean | Control modifier state |
| `alt_key` | boolean | Alt modifier state |
| `meta_key` | boolean | Command modifier state |
| `repeat` | boolean | Is key repeat |
| `is_composing` | boolean | Is composing (IME) |
| `sequence_number` | number | Monotonic event sequence |

### 7.3 Feature Extraction

From raw events, we compute two tiers of features:

**Tier 1 — Biometric signature (timing):**
- Flight time (inter-key interval): mean, std, median
- Hold time: mean, std
- Digraph matrix: timing statistics for every character pair
- Overlap ratio (roll typing detection)
- Typing speed (chars/min)

**Tier 2 — Error patterns:**
- Backspace rate, delete rate
- Error burst count and mean burst length
- Immediate correction ratio
- Revision ratio (corrections / total keystrokes)

### 7.4 Feature Vector Structure

Each behavioral commitment can include a feature vector:

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
│       ├── verification/    Bundle verification, chain integrity checks
│       └── atproto/         Lexicon definitions, AT Protocol client helpers
│
├── apps/ios-native/         Native SwiftUI iOS app
│   └── Speakwrite/
│       ├── Crypto/          SHA-256, commitment hashing (CryptoKit)
│       ├── Models/          SwiftData models
│       ├── Features/        Tier 1 + Tier 2 feature extraction
│       ├── Services/        ATProtoService, ProofService, DeviceAttestation, KeychainHelper
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
iOS Keyboard → CaptureTextView → Keystroke Events → SwiftData
                                        ↓
                                 Feature Extraction
                                        ↓
                              Commitment Chain (SHA-256)
                                        ↓
                          Secure Enclave Signing (P-256)
                                        ↓
                                Proof Bundle (JSON)
                                        ↓
                  AT Protocol (OAuth + DPoP) → AT Protocol Post
                                        ↓
                           Verified Feed in Speakwrite App
```

### 8.3 Storage

All data is local-first. SwiftData stores keystroke events, commitment chain entries, feature vectors, and document metadata. Nothing leaves the device until the user explicitly publishes.

DPoP key pairs and OAuth tokens are stored in the iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` protection.

---

## 9. Threat Model

### 9.1 What We Defend Against

| Attack | Defense |
|--------|---------|
| Copy-paste AI text | Observer detects non-typed input. Zero keystroke count. |
| Naive keystroke scripting | Behavioral features detect uniform timing. |
| Sophisticated simulation | High-dimensional feature space. Cross-feature correlations. |
| Post-signing modification | SHA-256 content hash binding. |
| Modified app binary | App Attest certificate proves unmodified code. |
| Spoofed attestation from web | Not possible — native binary only. No web wrapper. |
| Replay (reuse old proof) | Content hash binding to specific text. |

### 9.2 What We Don't Defend Against

| Attack | Why It Works |
|--------|-------------|
| Human transcription of AI text | Real typing produces real behavioral patterns. Cost: must type at human speed. |
| Jailbroken device | May circumvent Secure Enclave. |
| Reading AI output and retyping | Indistinguishable from original composition once internalized. |

### 9.3 Honest Assessment

Speakwrite makes deception expensive. It does not make it impossible. Verifying a post costs the reader nothing, but faking a proof costs the attacker significantly more than just prompting an LLM.

---

## 10. Open Questions

1. **Keystroke count threshold.** What's the minimum keystroke count for a credible proof?
2. **Behavioral baseline.** We extract features but don't yet compare them to a population baseline. v1 ships without a "human plausibility score" — just the raw features in the commitment chain.
3. **Progressive trust.** A single proof is weak evidence. A corpus of proofs from the same identity, exhibiting consistent behavioral patterns over time, is strong evidence.
4. **Cross-platform.** Android implementation would use Android's hardware attestation (SafetyNet / Play Integrity) and TEE-backed keystore. The proof bundle format is platform-agnostic.

---

*This spec describes what's built. Speakwrite is both a writing tool and a reader — one app for creating and consuming human-verified content. The protocol is the proof bundle JSON format — anyone can build a verifier or a compatible app.*
