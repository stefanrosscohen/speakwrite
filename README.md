# speakwrite

**Prove a human wrote it.**

Speakwrite is a native iOS app and open protocol for creating cryptographically verifiable proof that a post was typed by a human. It captures keystroke dynamics as you write, chains them into a tamper-evident commitment sequence, and signs every checkpoint with the iPhone's Secure Enclave.

The proof goes with the post. Anyone can verify it. No server, no API key, no trust required.

**[speakwrite.io](https://www.speakwrite.io)**

---

## Why

AI can produce text indistinguishable from human writing. Detection tools that analyze the *output* are losing an arms race they can never win — each new model evades the last detector.

Speakwrite takes a different approach: instead of analyzing what was written, it captures *how* it was written. The proof is in the process, not the product.

## How It Works

1. **Sign in** — Use your AT Protocol handle (OAuth with DPoP)
2. **Type** — Keystroke dynamics are captured natively as you write
3. **Commit** — Behavioral features are periodically hashed into a cryptographic commitment chain, signed by the Secure Enclave
4. **Publish** — The final content is bound to the chain tip; the proof bundle is published alongside your post on the AT Protocol network
5. **Verify** — Anyone can walk the hash chain, verify signatures, and confirm content binding

## The Protocol

The proof bundle is a portable JSON object with three layers:

- **Layer 1 — Cryptographic commitment chain:** SHA-256 hash chain makes the proof tamper-evident
- **Layer 2 — Device attestation:** Secure Enclave + App Attest signatures on every checkpoint
- **Layer 3 — Behavioral analysis:** Keystroke timing, digraph patterns, error correction rates

Full specification: [`SPEC-v1.md`](SPEC-v1.md)

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
- **Federated verification** — Any node on the network can independently verify a proof bundle with nothing but SHA-256
- **Open ecosystem** — No platform lock-in; any AT Protocol client can display and verify Speakwrite proofs

## Project Structure

```
speakwrite/
├── packages/core/         @speakwrite/core — reference TypeScript library
├── apps/ios-native/       Native SwiftUI iOS app (iOS 17+)
├── apps/desktop/          Tauri + React desktop app
├── apps/site/             Landing page (speakwrite.io)
└── SPEC-v1.md             Protocol specification
```

## What It Proves (and Doesn't)

**It proves:** A post was composed through physical typing on a genuine Apple device, with keystroke behavior consistent with human motor patterns, signed by hardware that never left the silicon.

**It doesn't prove:** That the ideas are original, that no AI was consulted, or that the author didn't retype something from another screen. It makes deception expensive — not impossible.

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
