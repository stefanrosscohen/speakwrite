# Speakwrite — Website Brief

## One-liner

Speakwrite is a native iOS app for writing and reading human-verified posts.

## Tagline

Write human. Read human.

## The Problem

AI can now produce text indistinguishable from human writing. Every detection tool that analyzes the *output* is losing an arms race it can never win. The next model will always evade the last detector.

Meanwhile, there's no place to go where everything you see was provably written by a person.

## The Approach

Speakwrite is two things in one app:

1. **A writing tool** that captures keystroke dynamics as you type and cryptographically signs each checkpoint with the iPhone's Secure Enclave. When you publish, the proof goes with the post.

2. **A reader** that shows a feed of all human-verified posts across the Bluesky network. One place where everything was typed by a human.

The result is a **proof bundle**: a portable, verifiable artifact that anyone can independently check. Hardware-backed by Apple's App Attest. No central authority. No API keys. No trust required.

## How It Works

1. **Sign in** — Sign in with your Bluesky handle. Face ID unlocks the Secure Enclave signing key.

2. **Write** — Type your post. Keystroke dynamics are captured natively — nothing leaves your device until you publish.

3. **Publish** — Speakwrite generates a cryptographic commitment chain signed by the Secure Enclave and publishes to Bluesky with the proof attached.

4. **Read** — Browse a global feed of all human-verified posts. Every post you see was typed by a person on a real device.

## What It Proves (and What It Doesn't)

**It proves:** A specific post was composed through physical typing on a genuine Apple device, authenticated by biometrics, with keystroke behavior consistent with human motor patterns.

**It doesn't prove:** That the ideas are original, that no AI was consulted, or that the author didn't transcribe AI output. It raises the cost of deception by orders of magnitude — it doesn't make it impossible.

This honesty is a design choice, not a limitation. Speakwrite produces forensic evidence, not mathematical certainty.

## Key Properties

- **Open protocol** — The proof bundle JSON format is the protocol. Anyone can build a verifier or a compatible app.
- **Hardware-backed** — Every proof is signed by the iPhone's Secure Enclave and certified by Apple's App Attest. No web fallback.
- **On-device** — Everything runs on your iPhone. No server sees your keystrokes. Only aggregate statistical features are committed.
- **Decentralized** — No central server, no trusted authority. Verification is pure cryptography (SHA-256 + P-256 ECDSA).
- **Progressive trust** — A single proof is weak evidence. A corpus of proofs from the same identity, exhibiting consistent behavioral patterns over time, is strong evidence.
- **Bluesky native** — Posts publish directly to your Bluesky account. The verified feed pulls from the entire AT Protocol network.

## For Whom

- **Writers** who want to say "I typed this" and have it mean something
- **Readers** who want a feed where everything was written by a human
- **Journalists** posting reporting they want attributed to a human author
- **Anyone** tired of wondering if the thing they're reading was written by a person

## Open Source

Speakwrite is open source under CC BY-SA 4.0. The protocol spec, app, and core library are all public.

- Protocol specification: `SPEC-v1.md`
- Reference library: `@speakwrite/core` (TypeScript, Web Crypto API)
- iOS app: Native SwiftUI (iOS 17+)

## Status

Working draft. The native iOS app and protocol spec are functional. The app writes verified posts and reads them in a global feed. The proof bundle format is stable enough to build on.

---

*Speakwrite does not solve the AI problem. It creates a new kind of evidence that didn't exist before — and a place to go where that evidence matters.*

*This document was not written by a human.*
