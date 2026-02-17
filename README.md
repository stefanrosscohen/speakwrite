# speakwrite

**Prove a human wrote it.**

Speakwrite is a native iOS app for creating cryptographically verifiable proof that a post was typed by a human on a genuine Apple device. It enforces input restrictions (soft keyboard only, no paste, no dictation, no autocorrect, no hardware keyboard), computes a SHA-256 content hash, and signs it with the iPhone's Secure Enclave via App Attest (P-256 ECDSA).

The proof goes with the post. Any reader's device can verify it. No server in the loop, no API key, no trust required.

**[speakwrite.io](https://www.speakwrite.io)**

---

## Why

AI can produce text indistinguishable from human writing. Detection tools that analyze the *output* are losing an arms race they can never win — each new model evades the last detector.

Speakwrite takes a different approach: instead of analyzing what was written, it captures *how* it was written. The proof is in the process, not the product.

## How It Works

1. **Sign in** — Use your AT Protocol handle (OAuth with DPoP)
2. **Type** — Input restricted to soft keyboard only — no paste, no dictation, no autocorrect, no hardware keyboard
3. **Publish** — SHA-256 content hash is computed and signed by App Attest (Secure Enclave P-256 ECDSA). The post is published to AT Protocol with `tags: ["speakwrite"]` for feed discovery. A proof record (`io.speakwrite.proof`) is stored alongside in the author's repository containing: postUri, keyId, attestationObject (Base64 CBOR), assertion (Base64 CBOR), contentHash (hex), and appId
4. **Verify** — Any reader's device fetches the proof from the author's PDS (resolved via PLC directory) and independently verifies it. Grey checkmark shows while verifying, green checkmark appears only when all cryptographic checks pass

## The Protocol

Each post is accompanied by a proof record (`io.speakwrite.proof`) stored in the author's AT Protocol repository. Verification is entirely client-side:

1. **Content binding** — `SHA-256(post_text)` must match the proof's `contentHash`
2. **Certificate chain** — CBOR-decode the attestation object, extract the x5c certs, validate the chain against Apple's App Attest Root CA
3. **Signature verification** — Extract the P-256 public key from the leaf certificate, CBOR-decode the assertion, verify the ECDSA signature over `SHA-256(authenticatorData || contentHash)`

No server in the verification loop. Proofs live on the author's AT Protocol Personal Data Server. Verification is pure cryptography: SHA-256, P-256 ECDSA, and Apple certificate chain validation.

Full specification with formal security analysis: [`SPEC-v1.md`](SPEC-v1.md)

## Security Properties

1. **Content binding** — `SHA-256(post_text)` must match the proof's content hash. Can't type A and publish B
2. **Signature unforgeability** — P-256 ECDSA assertion signed by the Secure Enclave. Can't forge without the hardware key
3. **Device authenticity** — App Attest certificate chain validates against Apple's Root CA. Proves the key is hardware-bound on a genuine Apple device running the unmodified binary
4. **Identity binding** — Proof is stored in the author's AT Protocol repository, referenced by post URI

## The App

Speakwrite is two things in one:

- **A writing tool** that enforces input restrictions and publishes hardware-signed proofs
- **A reader** with a verified feed that discovers posts via `tags: ["speakwrite"]`, where every post can be independently verified

Posts are discovered by the `#speakwrite` tag (which matches the tags array in the record). No footer text is appended to posts. Each reader's device independently validates the App Attest certificate chain and P-256 signature. A green checkmark appears only when the proof passes — no badge until proven.

Native SwiftUI. Full AT Protocol client — timeline, verified feed, compose, profiles, settings.

## Why AT Protocol

The AT Protocol is the natural home for verifiable human authorship:

- **Portable identity** — DIDs mean your proof history follows you across any service on the network
- **User-owned data** — Proof records live on the author's PDS, not a third-party server
- **Custom lexicons** — `io.speakwrite.proof` defines a structured record type any client can read and verify
- **Federated verification** — Any node on the network can independently verify a proof with nothing but SHA-256 and ECDSA
- **Open ecosystem** — No platform lock-in; any AT Protocol client can display and verify Speakwrite proofs

## Project Structure

```
speakwrite/
├── apps/ios-native/       Native SwiftUI iOS app (iOS 17+)
│                          (input restriction enforcement, SE signing, AT Protocol client)
├── apps/desktop/          Tauri + React desktop app
├── apps/site/             Landing page (speakwrite.io)
└── SPEC-v1.md             Protocol specification + security analysis
```

## What It Proves (and Doesn't)

**It proves:** A post was composed through physical typing on a genuine Apple device running the unmodified Speakwrite binary, with input restricted to soft keyboard only (no paste, no dictation, no autocorrect, no hardware keyboard), and every post signed by a hardware-bound key in the Secure Enclave.

**It doesn't prove:** That the ideas are original, that no AI was consulted, or that the author didn't retype something from another screen. It makes deception expensive — not impossible. Faking a proof requires a genuine device and typing each character on the soft keyboard. This is categorically harder than prompting an LLM.

## Development

```bash
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
