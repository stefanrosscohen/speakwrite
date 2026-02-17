# speakwrite

**Prove a human wrote it.**

Speakwrite is a native iOS app and open protocol for creating cryptographically verifiable proof that a post was typed by a human on a genuine Apple device. It captures keystroke dynamics as you write, chains them into openable commitments with document snapshots, and signs every checkpoint with the iPhone's Secure Enclave.

The proof goes with the post. Anyone can verify it. No server, no API key, no trust required.

**[speakwrite.io](https://www.speakwrite.io)**

---

## Why

AI can produce text indistinguishable from human writing. Detection tools that analyze the *output* are losing an arms race they can never win — each new model evades the last detector.

Speakwrite takes a different approach: instead of analyzing what was written, it captures *how* it was written. The proof is in the process, not the product.

## How It Works

1. **Sign in** — Use your AT Protocol handle (OAuth with DPoP)
2. **Authenticate** — Face ID gates every session (Secure Enclave biometric key)
3. **Type** — Keystroke dynamics captured natively via `pressesBegan`/`pressesEnded` (hardware keyboard) and `insertText`/`deleteBackward` (soft keyboard)
4. **Commit** — Every 60 seconds: behavioral features + a SHA-256 document snapshot are hashed into an openable commitment, signed by the Secure Enclave
5. **Publish** — Content is bound to the chain tip; the proof bundle (v2) is published alongside your post on the AT Protocol network
6. **Verify** — Anyone can re-derive every commitment hash, verify domain-separated P-256 ECDSA signatures, confirm content binding, and check keystroke plausibility

## The Protocol

The proof bundle is a portable JSON object verified in three layers:

- **Layer 1 — Cryptographic commitment chain:** SHA-256 hash chain with openable commitments. Each link binds behavioral features + document content snapshot. Any verifier can re-derive the hash and confirm it matches.
- **Layer 2 — Device attestation:** Secure Enclave P-256 ECDSA signatures on every checkpoint, verified against the device public key. Each signature carries a domain prefix (`speakwrite:checkpoint:`, `speakwrite:session:`, `speakwrite:binding:`) to prevent cross-type confusion. App Attest certifies the key is on a genuine Apple device running the unmodified binary.
- **Layer 3 — Behavioral analysis:** Keystroke timing (flight time, hold time, digraphs), error correction patterns, typing speed — committed as forensic evidence with plausibility checks. The protocol does not declare a threshold for "human enough" — behavioral features are evidence, not a verdict.

Full specification with formal security analysis: [`SPEC-v1.md`](SPEC-v1.md)

## Security Properties

The protocol provides six security properties (detailed in SPEC-v1.md §5.2):

1. **Chain immutability** — Can't modify behavioral data or document snapshots without breaking re-derivation (SHA-256 collision required)
2. **Content binding** — Can't type A and publish B; document hash at last checkpoint must match published content
3. **Signature unforgeability** — Can't forge checkpoint/binding signatures without the Secure Enclave key (ECDSA EU-CMA)
4. **Device authenticity** — App Attest proves the signing key is hardware-bound on a genuine Apple device running the unmodified app
5. **Human presence** — Biometric gate (Face ID) with `.biometryCurrentSet` access control on the SE key
6. **Identity binding** — Author's AT Protocol DID is signed into the session start, preventing proof replay under a different account

## The App

Speakwrite is two things in one:

- **A writing tool** that captures keystroke dynamics and publishes hardware-signed proofs
- **A reader** with a feed split into "Following" and "For You" sub-tabs, where every verified post was typed by a human

Verified posts are detected using the AT Protocol `tags` field on the post record -- no text footer or convention required. The app includes a full profile page with editing, photo pickers, and post management.

Native SwiftUI. Full AT Protocol client -- timeline, verified feed, compose, profiles, settings.

## Why AT Protocol

The AT Protocol is the natural home for verifiable human authorship:

- **Portable identity** — DIDs mean your proof history follows you across any service on the network
- **User-owned data** — Proof bundles live on the author's PDS, not a third-party server
- **Custom lexicons** — `io.speakwrite.proof` defines a structured record type any client can read and verify
- **Federated verification** — Any node on the network can independently verify a proof bundle with nothing but SHA-256 and ECDSA
- **Open ecosystem** — No platform lock-in; any AT Protocol client can display and verify Speakwrite proofs

## Project Structure

```
speakwrite/
├── packages/core/         @speakwrite/core — reference TypeScript library
│                          (verification, hashing, types)
├── apps/ios-native/       Native SwiftUI iOS app (iOS 17+)
│                          (keystroke capture, SE signing, AT Protocol client)
├── apps/desktop/          Tauri + React desktop app
├── apps/site/             Landing page (speakwrite.io)
└── SPEC-v1.md             Protocol specification + security analysis
```

## What It Proves (and Doesn't)

**It proves:** A post was composed through physical typing on a genuine Apple device running the unmodified Speakwrite binary, with biometric authentication, incremental behavioral data committed at each checkpoint, and every commitment signed by a hardware-bound key.

**It doesn't prove:** That the ideas are original, that no AI was consulted, or that the author didn't retype something from another screen. It makes deception expensive — not impossible. Faking a proof requires a genuine device, Face ID, and typing at human speed. This is categorically harder than prompting an LLM.

## Development

```bash
# Core library
pnpm build:core
pnpm test

# iOS app
open apps/ios-native/Speakwrite.xcodeproj
# Build with Xcode (iOS 17+, Swift 6)

# Desktop app (Tauri)
cd apps/desktop && pnpm tauri dev

# Website
pnpm dev:site
```

## License

CC BY-SA 4.0
