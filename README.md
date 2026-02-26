# speakwrite

**Prove a human wrote it.**

Speakwrite is a native iOS app and open protocol for creating cryptographically verifiable proof that a post was typed by a human on a genuine Apple device. It enforces input restrictions (soft keyboard only, no paste, no dictation, no autocorrect, no hardware keyboard), computes a SHA-256 content hash, and signs it with the iPhone's Secure Enclave via App Attest (P-256 ECDSA). Photos and videos are captured live through the device camera — no gallery picker — and their hashes are bound to the same attestation.

The proof goes with the post. Any reader's device can verify it. No server in the loop, no API key, no trust required.

**[speakwrite.io](https://www.speakwrite.io)** · **[Try the App](https://testflight.apple.com/join/TtPndBU4)** · **[@verify.speakwrite.io](https://bsky.app/profile/verify.speakwrite.io)** · **[Verify a Post](https://www.speakwrite.io/verify)**

---

## Why

AI can produce text indistinguishable from human writing. Detection tools that analyze the *output* are losing an arms race they can never win — each new model evades the last detector.

Speakwrite takes a different approach: instead of analyzing what was written, it captures *how* it was written. The proof is in the process, not the product.

## How It Works

1. **Sign in** — Use your AT Protocol handle (OAuth with DPoP)
2. **Type** — Input restricted to soft keyboard only — no paste, no dictation, no autocorrect, no hardware keyboard
3. **Capture media** — Photos and video recorded live through the device camera (no gallery, no uploads). Each media file is SHA-256 hashed at capture time
4. **Publish** — A content hash is computed and signed by App Attest (Secure Enclave P-256 ECDSA). The post is published to AT Protocol with `tags: ["speakwrite"]`. A proof record (`io.speakwrite.proof`) is stored in the author's repository
5. **Verify** — Any reader's device fetches the proof from the author's PDS (resolved via PLC directory) and independently verifies it. Grey checkmark while verifying, green checkmark when all cryptographic checks pass

## The Protocol

Each post is accompanied by a proof record (`io.speakwrite.proof`) stored in the author's AT Protocol repository. Verification is entirely client-side:

1. **Content binding** — Recompute the content hash and compare to the proof's `contentHash`
2. **Certificate chain** — CBOR-decode the attestation object, extract the x5c certs, validate the chain against Apple's App Attest Root CA
3. **Signature verification** — Extract the P-256 public key from the leaf certificate, CBOR-decode the assertion, verify the ECDSA signature over `SHA-256(authenticatorData || contentHash)`

No server in the verification loop. Proofs live on the author's AT Protocol Personal Data Server. Verification is pure cryptography: SHA-256, P-256 ECDSA, and Apple certificate chain validation.

### Content Hashing

- **Text-only posts:** `SHA-256(text)`
- **Posts with media:** `SHA-256(SHA-256(text) + sorted_media_sha256_bytes)` — composite hash binds both text and media to the same attestation

The composite hash scheme is backward-compatible: posts without media verify exactly as before.

### Proof Record Fields

| Field | Description |
|-------|-------------|
| `postUri` | AT URI of the post |
| `contentHash` | SHA-256 hex digest (text-only or composite) |
| `attestationObject` | Base64 CBOR — App Attest attestation with x5c cert chain |
| `assertion` | Base64 CBOR — P-256 ECDSA signature + authenticator data |
| `mediaHashes` | Optional array of SHA-256 hex digests of attached media |
| `createdAt` | ISO 8601 timestamp |

## Security Properties

1. **Content binding** — SHA-256 hash must match. Can't type A and publish B
2. **Signature unforgeability** — P-256 ECDSA signed by the Secure Enclave. Can't forge without the hardware key
3. **Device authenticity** — App Attest certificate chain validates against Apple's Root CA. Proves the key is hardware-bound on a genuine device running the unmodified binary
4. **Identity binding** — Proof is stored in the author's AT Protocol repository, referenced by post URI
5. **Media binding** — Composite hash ensures photos/videos are cryptographically bound to the attestation alongside text

## The App

Speakwrite is two things in one:

- **A writing tool** that enforces input restrictions, captures live media, and publishes hardware-signed proofs
- **A reader** with a verified feed where every post can be independently verified

Native SwiftUI. Full AT Protocol client — timeline, verified feed, compose with camera capture, profiles, post detail with threads, @mention linking, image/video rendering.

### Tabs

- **Timeline** — Your Bluesky home feed with client-side verification badges
- **Verified** — Posts tagged `speakwrite` — every one typed by a human on a real device
- **Compose** — Input-restricted editor with camera capture for attested photos and video (up to 4 photos or 1 video)
- **Profile** — Your posts, followers, following

## Verification Bot

[`@verify.speakwrite.io`](https://bsky.app/profile/verify.speakwrite.io) — mention it under any post on Bluesky and it runs the full cryptographic verification pipeline:

- **Content hash** — Recomputes SHA-256 from post text and media
- **Certificate chain** — Validates x5c against Apple's App Attest Root CA
- **ECDSA signature** — Verifies the Secure Enclave assertion
- Replies with results and a link to independent web verification
- TypeScript service on Fly.io · Source: `apps/speakwrite-bot/`

## Web Verification

Every Speakwrite post includes a verify link pointing to `www.speakwrite.io/verify/{handle}/{rkey}`. The web page fetches the proof record and runs client-side verification using Web Crypto — no server, no backend, just cryptography in the browser.

## Project Structure

```
speakwrite/
├── apps/
│   ├── ios-native/          Native SwiftUI iOS app (iOS 17+)
│   │   └── Speakwrite/
│   │       ├── Services/    AT Protocol client, App Attest, verification, input restriction
│   │       ├── ViewModels/  App state, publish pipeline with blob upload
│   │       ├── Views/       Feed, timeline, compose, camera, profiles, post detail
│   │       └── Features/    Mention picker
│   ├── speakwrite-bot/      Verification bot (TypeScript, Fly.io)
│   │   └── src/             Bot logic, AT Protocol client, verification
│   ├── site/                Landing page + web verifier (GitHub Pages)
│   │   ├── index.html       speakwrite.io
│   │   └── verify/          Client-side web verification page
```

## What It Proves (and Doesn't)

**It proves:** A post was composed through physical typing on a genuine Apple device running the unmodified Speakwrite binary, with input restricted to soft keyboard only. Photos and videos were captured live through the device camera. Everything is signed by a hardware-bound key in the Secure Enclave.

**It doesn't prove:** That the ideas are original, that no AI was consulted, or that the author didn't retype something from another screen. It makes deception expensive — not impossible. Faking a proof requires a genuine device and typing each character on the soft keyboard.

## Why AT Protocol

- **Portable identity** — DIDs mean your proof history follows you across any service on the network
- **User-owned data** — Proof records live on the author's PDS, not a third-party server
- **Custom lexicons** — `io.speakwrite.proof` defines a structured record type any client can read and verify
- **Federated verification** — Any node on the network can independently verify a proof with SHA-256 and ECDSA
- **Open ecosystem** — No platform lock-in; any AT Protocol client can display and verify Speakwrite proofs

## Development

```bash
# iOS app — requires Xcode 15+, iOS 17+, physical device for App Attest
open apps/ios-native/Speakwrite.xcodeproj

# Verification bot — requires Node.js 18+
cd apps/speakwrite-bot && npm install && npm run build && npm start

# Deploy bot to Fly.io
cd apps/speakwrite-bot && fly deploy

# Website — static files, GitHub Pages auto-deploys on push
```

## License

CC BY-SA 4.0
