# Speakwrite v1 Specification

**Version:** 1.0-draft
**Status:** Working Draft
**Date:** 2026-02-14
**Authors:** Stefan Cohen

---

## 1. What This Is

Speakwrite is a protocol that lets you prove you typed something on a real iPhone. You write a post in the Speakwrite app, it captures your keystroke timing, and when you publish, the proof goes with the post. Anyone can verify it.

**Scope of v1:** iPhone app. Short-form posts (think Bluesky-length, up to ~5,000 chars). Published via AT Protocol. Verified via an open JSON bundle.

**What it proves:** A specific post was composed through physical typing on a genuine Apple device, authenticated by Face ID, with behavioral keystroke patterns consistent with human typing.

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
│  Face ID biometric gate                     │
├─────────────────────────────────────────────┤
│  Layer 1: Cryptographic Commitment Chain    │
│  SHA-256 hash chain → tamper-evident        │
└─────────────────────────────────────────────┘
```

**Layer 1** makes it tamper-evident. Each checkpoint during writing creates a hash that includes the previous hash, forming a chain. You can't edit the chain after the fact without breaking it.

**Layer 2** makes it hardware-backed. The iPhone's Secure Enclave (a separate chip on the device) holds a signing key that never leaves the silicon. Apple's App Attest service certifies the key was generated on a real iPhone running your unmodified app. Face ID gates every session — no face, no signing.

**Layer 3** makes it behaviorally credible. Human typing has distinct statistical properties: variable inter-key timing, characteristic digraph patterns (the time between specific key pairs), natural pause distributions, error-and-correct patterns. The protocol captures these and includes them in the proof.

### 2.2 Session Lifecycle

```
1. User opens app → Face ID prompt → Secure Enclave key unlocked
2. User starts typing → Observer captures keystroke events
3. Every ~60 seconds → Checkpoint:
   - Extract behavioral features from keystrokes
   - Compute commitment hash (chained to previous)
   - Sign commitment with Secure Enclave key
4. User hits "Publish" →
   - Final content binding: SHA-256(content) bound to chain tip
   - Sign final binding with Secure Enclave key
   - Assemble proof bundle (JSON)
   - Publish to AT Protocol (Bluesky)
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
      },
      {
        "sequence_num": 1,
        "commitment_hash": "sha256:...",
        "signature": "base64(P-256 ECDSA)..."
      }
    ],
    "final_signature": "base64(P-256 ECDSA over content_hash|binding_hash)..."
  }
}
```

---

## 3. Verification

Anyone can verify a proof bundle. No server, no API key, no trust required.

### 3.1 Steps

1. **Content hash:** Compute `SHA-256(post_content)`. Compare to `content_hash` in bundle.
2. **Chain integrity:** Walk the commitment chain. Each `commitment_hash` at position N should reference `commitment_hash` at position N-1 as its `previous_hash`. The chain must be monotonically increasing in `timestamp_ms`.
3. **Content binding:** The final commitment (type `content_binding`) must reference the content hash and the chain tip.
4. **Device attestation (if present):**
   - Verify the `attestation_certificate` chains to Apple's App Attest Root CA.
   - Extract the public key from the certificate.
   - Verify each `checkpoint_signature` against the public key and the corresponding `commitment_hash`.
   - Verify the `final_signature` against the public key and `content_hash|binding_hash`.
5. **Behavioral plausibility (optional):** Check that `total_keystroke_count` is plausible for the content length. A 500-word post with 3 keystrokes is suspicious.

### 3.2 Attestation Levels

| Level | Label | What It Means |
|-------|-------|--------------|
| 0 | `none` | Commitment chain only. Tamper-evident but no device proof. |
| 4 | `platform_attested` | Apple App Attest + Secure Enclave + Face ID. Strongest available. |

v1 only ships levels 0 (web fallback) and 4 (iPhone app). No middle ground.

### 3.3 What Verification Tells You

A valid proof with `platform_attested` means:

- The post content has not been modified since signing.
- The commitment chain was built incrementally over time (not fabricated all at once).
- Each checkpoint was signed by a Secure Enclave key on a genuine Apple device.
- Apple certifies the signing key belongs to the unmodified Speakwrite app.
- Face ID confirmed a real person was present at session start.
- The keystroke count is consistent with the content length.

A valid proof does NOT tell you:
- Whether the author was reading from another screen.
- Whether AI helped with ideation.
- Whether the content is true or well-reasoned.

---

## 4. Distribution: AT Protocol

### 4.1 Why AT Protocol

- Open protocol — no platform lock-in.
- User-owned data — proofs live in the author's Personal Data Server (PDS).
- Federation — any PDS can host proofs, any client can verify them.
- Bluesky is the primary social layer with ~25M users.

### 4.2 Custom Lexicon

Proofs are stored as records in the author's AT Protocol repo under a custom collection:

**Collection:** `io.speakwrite.proof`

```json
{
  "$type": "io.speakwrite.proof",
  "contentHash": "sha256:...",
  "bindingHash": "sha256:...",
  "chainLength": 3,
  "totalKeystrokes": 847,
  "proofBundle": "{...json string...}",
  "verifierUrl": "https://verify.speakwrite.io?bundle=...",
  "createdAt": "2026-02-14T12:00:00Z"
}
```

### 4.3 Social Post

When publishing, the app also creates a `app.bsky.feed.post` record with:
- The post text.
- A link facet pointing to the verification URL.
- A reference to the proof record.

Readers see a normal Bluesky post with a "Verify" link.

### 4.4 Authentication

OAuth 2.0 with PKCE + DPoP per the AT Protocol specification. The user signs in with their Bluesky handle — the app redirects to their PDS authorization page and receives tokens automatically. No app passwords.

---

## 5. Device Attestation: Apple Implementation

### 5.1 Hardware

Every iPhone since the 5s (2013) has a Secure Enclave — a dedicated security coprocessor with its own encrypted memory, hardware random number generator, and AES engine. Private keys generated in the Secure Enclave never exist in main memory.

### 5.2 Key Generation

On first app launch:

1. **App Attest key:** `DCAppAttestService.shared.generateKey()` creates a P-256 key pair in the Secure Enclave. Apple's attestation service issues a certificate chain proving the key is on a real device running unmodified Speakwrite.

2. **Session signing key:** `SecureEnclave.P256.Signing.PrivateKey(accessControl:)` creates a biometric-gated key. The `accessControl` flags require `.biometryCurrentSet` — the key can only sign when the currently enrolled Face ID/Touch ID matches.

### 5.3 Session Signing

Every checkpoint and the final content binding are signed with the biometric-gated Secure Enclave key. The signature covers `sequence_num|commitment_hash` for checkpoints and `content_hash|binding_hash` for the final binding.

### 5.4 What Apple Certifies

The App Attest certificate chain proves:
- The key was generated on a genuine Apple device with a Secure Enclave.
- The key is bound to bundle ID `io.speakwrite.app`.
- The device has not been flagged by Apple.

### 5.5 Limitations

- **Jailbroken devices** may be able to circumvent Secure Enclave protections.
- **App Attest** proves the app is genuine, not that the keystrokes are genuine. A sophisticated attacker could theoretically inject programmatic keystrokes within the app's process before signing. This is where the behavioral analysis layer provides defense-in-depth.
- **No keyboard attestation.** iOS does not provide a mechanism for the system keyboard to sign its own output. The gap between "physical key press" and "signed data" is bridged by behavioral analysis, not cryptography.

---

## 6. Behavioral Capture

### 6.1 What We Capture

The Observer hooks into the TipTap editor's input events and records:

| Event | Data | Purpose |
|-------|------|---------|
| keydown | key, code, timestamp, modifiers | Raw keystroke timing |
| keyup | key, code, timestamp | Dwell time calculation |
| input | inputType, data, timestamp | What actually changed in the editor |
| paste | — | Flagged as non-typed content |
| delete | — | Revision pattern tracking |

All timestamps use `performance.now()` for sub-millisecond resolution.

### 6.2 Feature Extraction

From raw events, we compute two tiers of features:

**Tier 1 (basic):**
- Mean, median, stddev of inter-key intervals
- Typing speed (chars/min, words/min)
- Error rate (backspace ratio)
- Pause distribution (short <300ms, medium 300ms-2s, long >2s)
- Session duration

**Tier 2 (advanced):**
- Digraph timing: mean/stddev for frequent key pairs
- Burst detection: sequences of fast typing followed by pauses
- Revision patterns: delete-retype sequences
- Typing rhythm regularity (coefficient of variation)

### 6.3 What Human Typing Looks Like

Human typing is messy in characteristic ways:
- Inter-key intervals follow a log-normal distribution, not uniform or Gaussian.
- Specific key pairs have consistent but individual timing (your `th` timing is different from mine).
- Pauses cluster at linguistic boundaries (sentence ends, paragraph breaks).
- Error rates correlate with typing speed (faster = more mistakes).
- There are micro-pauses for thought that are absent in transcription.

Programmatic text generation produces none of these patterns. A naive script produces perfectly uniform timing. A sophisticated script can approximate the distributions but struggles with the cross-correlations between features.

---

## 7. Architecture

### 7.1 Monorepo Structure

```
speakwrite/
├── packages/core/     @speakwrite/core — shared TypeScript library
│   ├── crypto/        SHA-256, commitment hashing, content binding
│   ├── features/      Tier 1 + Tier 2 feature extraction
│   ├── capture/       Event validation
│   ├── verification/  Bundle + chain verification
│   ├── atproto/       AT Protocol lexicon + client
│   └── types/         ProofBundle, DeviceAttestation, etc.
│
├── apps/web/          PWA — works in browser (attestation level 0)
│   ├── components/    Editor, ProofSidebar, PublishPanel
│   ├── lib/services/  session, proof, atproto, device-attestation
│   └── stores/        Zustand state management
│
├── apps/ios/          Capacitor iOS shell (attestation level 4)
│   └── ios/App/       Swift native plugin for App Attest + Secure Enclave
│
└── apps/verifier/     Standalone verification page
    └── components/    VerifyForm, VerifyResult, ChainVisualization
```

### 7.2 Data Flow

```
iPhone Keyboard → TipTap Editor → Keystroke Observer → IndexedDB
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
                          Anyone → Verify at verify.speakwrite.io
```

### 7.3 Storage

All data is local-first. IndexedDB via Dexie.js stores:
- Keystroke events (per session)
- Commitment chain entries
- Feature vectors
- Document metadata

Nothing leaves the device until the user explicitly publishes.

---

## 8. Threat Model (Simplified)

### 8.1 What We Defend Against

| Attack | Difficulty | Defense |
|--------|-----------|---------|
| Copy-paste AI text | Trivial | Observer flags paste events. Zero keystroke count. |
| Naive keystroke scripting | Low | Behavioral features detect uniform/Gaussian timing. |
| Sophisticated simulation | High | High-dimensional feature space. Cross-feature correlations. Progressive consistency. |
| Post-signing modification | Impossible | SHA-256 content hash binding. |
| Modified app binary | Moderate | App Attest certificate proves unmodified code. |
| Replay (reuse old proof) | Impossible | Content hash binding to specific text. |

### 8.2 What We Don't Defend Against

| Attack | Why It Works |
|--------|-------------|
| Human transcription of AI text | Real human typing produces real behavioral patterns. Cost: must type at human speed. |
| Jailbroken device | May circumvent Secure Enclave. Apple flags some jailbreaks but not all. |
| Reading AI output and retyping from memory | Indistinguishable from original composition once internalized. |

### 8.3 Honest Assessment

Speakwrite makes deception expensive. It does not make it impossible. The value proposition is that verifying a post costs the reader nothing, but faking a proof costs the attacker significantly more than just prompting an LLM.

---

## 9. Integration with Blog Platforms

### 9.1 Verification Widget

Any website can embed a verification widget. The widget:

1. Fetches the proof bundle from the post's AT Protocol record.
2. Runs SHA-256 verification client-side (zero server trust).
3. Checks the device attestation certificate chain.
4. Displays an attestation badge.

### 9.2 Badge Levels

For v1, two badges:

**"iPhone Verified"** — Full device attestation. Apple Secure Enclave signed every checkpoint. Face ID confirmed.

**"Keystroke Verified"** — Commitment chain valid, no device attestation. The web fallback.

### 9.3 Embeddable Snippet

Blog platforms can verify Speakwrite proofs with a single script tag:

```html
<script src="https://verify.speakwrite.io/widget.js"
        data-at-uri="at://did:plc:xxx/io.speakwrite.proof/rkey"></script>
```

The widget resolves the AT URI, fetches the proof, verifies it client-side, and renders a badge inline. No server roundtrip.

### 9.4 Platform Integration Path

| Platform | Integration Method |
|----------|-------------------|
| Bluesky | Native — proofs stored in user's PDS, link in post |
| Substack | Embed widget in post footer |
| Ghost | Custom card or HTML embed |
| WordPress | Shortcode or plugin |
| Medium | Not possible (no custom HTML) — link to verifier instead |
| Personal blog | Script tag embed |

---

## 10. What's Not in v1

The following are explicitly deferred:

- **World ID / personhood verification.** Adds Sybil resistance but requires dependency on Worldcoin. Deferred to v2.
- **Zero-knowledge behavioral proofs.** Would hide behavioral data from verifiers. Requires ZK circuit engineering. Research-stage.
- **Collaborative writing.** Multi-author attribution. Achievable but not needed for short-form posts.
- **Android support.** Play Integrity + StrongBox Keystore. Similar architecture, different native code.
- **Voice input.** Fundamentally different behavioral signal. Needs separate feature extractor.
- **Desktop hardware attestation.** TPM integration varies wildly across hardware.
- **Long-form document support.** v1 targets posts, not essays.
- **Decentralized timestamping.** OpenTimestamps or similar. Nice to have, not essential for v1.

---

## 11. Open Questions

1. **Keystroke count threshold.** What's the minimum keystroke count for a credible proof? 50? 100? Needs empirical data.
2. **Checkpoint interval.** Currently ~60 seconds. Should this be adaptive (based on typing activity)?
3. **Behavioral baseline model.** We extract features but don't yet compare them to a population baseline. v1 ships without a "human plausibility score" — just the raw features in the commitment chain.
4. **App Store review.** Apple may scrutinize the DeviceCheck/App Attest usage. Need to ensure compliance with App Store guidelines on attestation APIs.
5. **Post length limits.** Bluesky posts are 300 chars. Our proof records can be longer. Should we also support longer-form (1,000-5,000 char) posts via a different Bluesky record type or external hosting?

---

*This spec describes what we're building. The full research spec is in SPEC.md.*
