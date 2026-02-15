# Speakwrite v1 Specification

**Version:** 1.0-draft
**Status:** Working Draft
**Date:** 2026-02-14
**Authors:** Stefan Cohen

---

## 1. What This Is

Speakwrite is a native iOS app for writing and reading human-verified posts. It is two things in one:

1. **A writing tool** that captures keystroke dynamics as you type, cryptographically signs each checkpoint with the iPhone's Secure Enclave, and publishes the proof alongside the post.

2. **A reader** that shows a global feed of all human-verified posts across the Bluesky network — one place where everything was typed by a person.

**Scope of v1:** Native SwiftUI iOS app. Short-form posts (up to ~5,000 chars). Published via AT Protocol. Verified via an open JSON bundle. Hardware attestation via Apple App Attest + Secure Enclave on every proof. Global verified feed for reading.

**What it proves:** A specific post was composed through physical typing on a genuine Apple device, authenticated by biometrics, with keystroke behavior consistent with human motor patterns.

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
│  Face ID / Touch ID biometric gate          │
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
1. User opens app → signs in with Bluesky handle (OAuth)
2. Face ID prompt → Secure Enclave key unlocked
3. User starts typing → Observer captures keystroke events
4. Periodically → Checkpoint:
   - Extract behavioral features from keystrokes
   - Compute commitment hash (chained to previous)
   - Sign commitment with Secure Enclave key
5. User hits "Publish" →
   - Final content binding: SHA-256(content) bound to chain tip
   - Sign final binding with Secure Enclave key
   - Assemble proof bundle (JSON)
   - Publish to AT Protocol
```

### 2.3 The Proof Bundle

The proof bundle is a JSON object. This IS the protocol — anyone who can compute SHA-256 can verify it.

```json
{
  "version": "1.0.0",
  "document_id": "uuid",
  "content_hash": "sha256:abc123...",
  "binding_hash": "sha256:def456...",
  "total_keystroke_count": 847,
  "created_at": "2026-02-14T12:00:00Z",

  "commitments": [
    {
      "sequence_num": 0,
      "commitment_hash": "sha256:...",
      "previous_hash": null,
      "nonce": "hex...",
      "timestamp_ms": 1739530800000,
      "commitment_type": "behavioral",
      "content_hash": null
    },
    {
      "sequence_num": 1,
      "commitment_hash": "sha256:...",
      "previous_hash": "sha256:...",
      "nonce": "hex...",
      "timestamp_ms": 1739530860000,
      "commitment_type": "behavioral",
      "content_hash": null
    },
    {
      "sequence_num": 2,
      "commitment_hash": "sha256:...",
      "previous_hash": "sha256:...",
      "nonce": "",
      "timestamp_ms": 1739530920000,
      "commitment_type": "content_binding",
      "content_hash": "sha256:abc123..."
    }
  ],

  "device_attestation": {
    "platform": "apple",
    "attestation_type": "app_attest",
    "attestation_level": "platform_attested",
    "device_public_key": "base64...",
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
        "commitment_hash": "sha256:...",
        "signature": "base64(P-256 ECDSA)..."
      }
    ],
    "final_signature": "base64(P-256 ECDSA over content_hash|binding_hash)..."
  }
}
```

Every proof from Speakwrite includes `device_attestation` because the entire app is native iOS. There is no web fallback.

---

## 3. Verification

Anyone can verify a proof bundle. No server, no API key, no trust required.

### 3.1 Steps

1. **Content hash:** Compute `SHA-256(post_content)`. Compare to `content_hash` in bundle.
2. **Chain integrity:** Walk the commitment chain. Each `commitment_hash` at position N must reference the hash at position N-1 as its `previous_hash`. Timestamps must be monotonically increasing.
3. **Content binding:** The final commitment (type `content_binding`) must bind the content hash to the chain tip via `SHA-256(chain_tip || "CONTENT_BINDING" || content_hash)`.
4. **Device attestation:**
   - Verify the `attestation_certificate` chains to Apple's App Attest Root CA.
   - Verify each `checkpoint_signature` against the public key and corresponding `commitment_hash`.
   - Verify the `final_signature` against the public key and `content_hash|binding_hash`.
5. **Behavioral plausibility (optional):** Check that `total_keystroke_count` is plausible for the content length.

---

## 4. Distribution: AT Protocol

### 4.1 Why AT Protocol

- Open protocol — no platform lock-in.
- User-owned data — proofs live in the author's Personal Data Server (PDS).
- Federation — any PDS can host proofs, any client can verify them.

### 4.2 Custom Lexicon

Proofs are stored as records in the author's AT Protocol repo under a custom collection:

**Collection:** `io.speakwrite.proof`

```json
{
  "$type": "io.speakwrite.proof",
  "proof": "{...json string of full proof bundle...}",
  "postUri": "at://did:plc:xxx/app.bsky.feed.post/rkey",
  "createdAt": "2026-02-14T12:00:00Z"
}
```

### 4.3 Social Post

When publishing, the app creates an `app.bsky.feed.post` record with the post text and a keystroke/commitment count footer. A companion `io.speakwrite.proof` record stores the full proof bundle.

### 4.4 Authentication

OAuth 2.0 with PKCE + DPoP per the AT Protocol specification, via ASWebAuthenticationSession. The user signs in with their Bluesky handle.

### 4.5 Verified Feed (Reader)

The app includes a global feed of all Speakwrite-verified posts across the AT Protocol network. This is the reader half of the app — a single place where every post was typed by a person on a real device. The feed uses `app.bsky.feed.searchPosts` to find posts with the Speakwrite keystroke/commitment footer pattern, then displays them in reverse chronological order with author info, verification badges, and keystroke/commitment counts.

---

## 5. Device Attestation: Apple Implementation

### 5.1 How It Works

On first launch, the app generates two keys in the Secure Enclave:

1. **App Attest key** — Apple's attestation service issues a certificate chain proving the key is on a real device running the unmodified app.
2. **Session signing key** — A biometric-gated P-256 key that can only sign when Face ID / Touch ID confirms the user.

Every checkpoint and the final content binding are signed with the biometric-gated key. The signature covers `sequence_num|commitment_hash` for checkpoints and `content_hash|binding_hash` for the final binding.

### 5.2 Why Native

Hardware attestation requires a native binary. A web app cannot do this because:
- App Attest certifies a specific app binary — there is no web equivalent.
- Secure Enclave signing requires native keychain access.
- Any client can spoof web requests, making browser-based attestation meaningless.

The entire proof chain — from keystroke capture through Secure Enclave signing — happens inside the native binary. There is no JavaScript bridge or web wrapper.

### 5.3 Limitations

- **Jailbroken devices** may circumvent Secure Enclave protections.
- **No keyboard attestation.** iOS does not let the system keyboard sign its own output. The gap between "physical key press" and "signed data" is bridged by behavioral analysis, not cryptography.

---

## 6. Behavioral Capture

### 6.1 What We Capture

A custom UITextView subclass captures keystroke events natively:

| Event | Data | Purpose |
|-------|------|---------|
| insertText / pressesBegan | key, code, timestamp, modifiers | Raw keystroke timing |
| deleteBackward / pressesEnded | key, code, timestamp | Hold time / correction tracking |
| setMarkedText / unmarkText | — | IME composition tracking |

Timestamps use `ProcessInfo.processInfo.systemUptime` for sub-millisecond resolution.

### 6.2 Feature Extraction

From raw events, we compute two tiers of features:

**Tier 1 (biometric signature):**
- Flight time (inter-key interval): mean, std, median
- Hold time: mean, std
- Digraph matrix: timing stats for every character pair
- Overlap ratio (roll typing detection)
- Typing speed (chars/min)

**Tier 2 (error patterns):**
- Backspace rate, delete rate
- Error burst count and mean burst length
- Immediate correction ratio
- Revision ratio (corrections / total keystrokes)

---

## 7. Architecture

### 7.1 Project Structure

```
speakwrite/
├── packages/core/         @speakwrite/core — reference TypeScript library
│
├── apps/ios-native/       Native SwiftUI iOS app
│   └── Speakwrite/
│       ├── Crypto/        SHA-256, commitment hashing (CryptoKit)
│       ├── Models/        SwiftData models
│       ├── Features/      Tier 1 + Tier 2 feature extraction
│       ├── Services/      DeviceAttestation, Session, Proof, ATProto
│       ├── Views/         SwiftUI views (Login, Editor, Feed, Publish)
│       └── ViewModels/    App state (@Observable)
│
└── apps/site/             Landing page (speakwrite.io)
```

### 7.2 Data Flow

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
                            AT Protocol → Bluesky Post
                                        ↓
                           Verified Feed in Speakwrite App
```

### 7.3 Storage

All data is local-first. SwiftData stores keystroke events, commitment chain entries, feature vectors, and document metadata. Nothing leaves the device until the user explicitly publishes.

---

## 8. Threat Model

### 8.1 What We Defend Against

| Attack | Defense |
|--------|---------|
| Copy-paste AI text | Observer detects non-typed input. Zero keystroke count. |
| Naive keystroke scripting | Behavioral features detect uniform timing. |
| Sophisticated simulation | High-dimensional feature space. Cross-feature correlations. |
| Post-signing modification | SHA-256 content hash binding. |
| Modified app binary | App Attest certificate proves unmodified code. |
| Spoofed attestation from web | Not possible — native binary only. No web wrapper. |
| Replay (reuse old proof) | Content hash binding to specific text. |

### 8.2 What We Don't Defend Against

| Attack | Why It Works |
|--------|-------------|
| Human transcription of AI text | Real typing produces real behavioral patterns. Cost: must type at human speed. |
| Jailbroken device | May circumvent Secure Enclave. |
| Reading AI output and retyping | Indistinguishable from original composition once internalized. |

### 8.3 Honest Assessment

Speakwrite makes deception expensive. It does not make it impossible. Verifying a post costs the reader nothing, but faking a proof costs the attacker significantly more than just prompting an LLM.

---

## 9. Open Questions

1. **Keystroke count threshold.** What's the minimum keystroke count for a credible proof?
2. **Behavioral baseline.** We extract features but don't yet compare them to a population baseline. v1 ships without a "human plausibility score" — just the raw features in the commitment chain.
3. **Progressive trust.** A single proof is weak evidence. A corpus of proofs from the same identity, exhibiting consistent behavioral patterns over time, is strong evidence.

---

*This spec describes what's built. Speakwrite is both a writing tool and a reader — one app for creating and consuming human-verified content. The protocol is the proof bundle JSON format — anyone can build a verifier or a compatible app.*
