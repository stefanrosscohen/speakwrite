# Speakwrite — Website Brief

## One-liner

Speakwrite is an iPhone app that proves a human typed a post.

## Tagline

Prove a human wrote it. Not by analyzing the output — by witnessing the process.

## The Problem

AI can now produce text indistinguishable from human writing. Every detection tool that analyzes the *output* is losing an arms race it can never win. The next model will always evade the last detector.

## The Approach

Speakwrite takes a fundamentally different approach: instead of analyzing what was written, it instruments *how* it was written. The app captures keystroke dynamics — timing, rhythm, pauses, corrections — as you type, and cryptographically binds that behavioral evidence to the resulting post.

On iPhone, every session is authenticated by Face ID and backed by hardware attestation (Apple App Attest + Secure Enclave). The proof isn't just software — it's tied to a real device and a real person.

The result is a **proof bundle**: a portable, verifiable artifact that anyone can independently check. No central authority. No API keys. No trust required.

## How It Works

1. **Open** — Launch Speakwrite on your iPhone. Face ID authenticates you and unlocks your Secure Enclave signing key.

2. **Write** — Type your post. Keystroke dynamics are captured locally — nothing leaves your device until you publish.

3. **Publish** — Speakwrite generates a cryptographic commitment chain binding your behavioral evidence to your post, signs it with the Secure Enclave, and publishes to Bluesky.

4. **Verify** — Anyone can verify the proof bundle in their browser. The verifier is open source and runs entirely client-side.

## What It Proves (and What It Doesn't)

**It proves:** A post was composed through physical typing on a genuine Apple device, authenticated by Face ID, with keystroke behavior consistent with human motor patterns.

**It doesn't prove:** That the ideas are original, that no AI was consulted, or that the author didn't transcribe AI output. It raises the cost of deception by orders of magnitude — it doesn't make it impossible.

This honesty is a design choice, not a limitation. Speakwrite produces forensic evidence, not mathematical certainty.

## Key Properties

- **Hardware-attested** — Apple App Attest + Secure Enclave + Face ID. Proofs are tied to a real device and a real person.
- **Open protocol** — The proof bundle JSON format is the protocol. Anyone can build a verifier or a compatible app.
- **Privacy-preserving** — Raw keystrokes never leave your device. Only aggregate statistical features are committed.
- **Decentralized** — No central server, no trusted authority. Verification is pure client-side cryptography (SHA-256).
- **Progressive trust** — A single proof is weak evidence. A corpus of proofs from the same identity, exhibiting consistent behavioral patterns over time, is strong evidence.
- **Bluesky native** — Posts publish directly to your Bluesky account as standard posts with proof metadata.

## For Whom

- **Anyone on Bluesky** who wants to say "I typed this" and have it mean something
- **Journalists** posting reporting they want attributed to a human author
- **Writers** who want provenance for posts where human authorship matters
- **Anyone** tired of wondering if the thing they're reading was written by a person

## Open Source

Speakwrite is open source under CC BY-SA 4.0. The protocol spec, app, verifier, and core library are all public.

- Protocol specification: `SPEC-v1.md`
- Core library: `@speakwrite/core` (TypeScript, Web Crypto API)
- iPhone app: Capacitor + native Swift (App Attest, Secure Enclave)
- Verifier: Standalone client-side verification page

## Status

Working draft. The iPhone app, protocol spec, and verifier are functional. Proofs publish as Bluesky posts. The proof bundle format is stable enough to build on.

---

*Speakwrite does not solve the AI problem. It creates a new kind of evidence that didn't exist before.*
