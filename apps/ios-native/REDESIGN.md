# iOS Redesign & Hardening Pass — August 2026

This pass covers three things: a diagnosis of why the app stopped working, a
visual/design rethink, and a functionality pass. All changes are in this
directory unless noted.

## Why the app "isn't working" — diagnosis

Everything in the stack was probed live:

| Component | Status |
|---|---|
| speakwrite.io site + `/verify` + `app/client-metadata.json` | ✅ up |
| Bluesky public AppView (`api.bsky.app`, `#speakwrite` search) | ✅ up |
| Verification bot (`speakwrite-bot.fly.dev/health`) | ✅ up |
| Bot PDS (`verify.speakwrite.io`, PDS v0.4.208) | ✅ up |
| **Your PDS (`pds.stefans.house`)** | ❌ **down — connection reset** |

Your account (`stefans.house`, `did:plc:df3nqdffqwwyvgl3geo2grwo`) lives on a
self-hosted PDS at `pds.stefans.house`, and that server is refusing
connections. Because the app routes sign-in (OAuth discovery), the Following
feed, profile loads, publishing, *and* proof verification of your posts
through your PDS, a dead PDS made the whole app look broken:

- **Sign-in** hung ~60s on `/.well-known/oauth-protected-resource`, then failed generically.
- **Session restore** → every authenticated request failed or hung.
- **Verification of your posts** failed — proof records live on your PDS.

**The fix on the infra side is restarting/repairing `pds.stefans.house` —
that's outside this repo.** The app-side changes below make the app degrade
gracefully instead of appearing dead.

## Resilience fixes (app now survives a dead PDS)

- **15-second request timeouts** via a shared `URLSession` (was the 60s default) — failures are fast and explicit.
- **Public AppView fallback**: For You feed, profiles, author feeds, and threads fall back to `api.bsky.app` when the PDS errors. Following feed can't (auth-only), so it now flags the outage instead.
- **`pdsUnreachable` state + banner**: the Feed tab shows "Your data server isn't responding — showing public feeds"; Settings shows the PDS host with a warning glyph.
- **Sign-in error clarity**: a dead PDS now reports "Your data server (host) isn't responding" instead of a generic failure.
- **Verification `unavailable` state**: a transient network failure while fetching proofs is no longer cached forever as "failed"; pull-to-refresh retries it.

## Other bugs fixed

- DPoP `htu` claim included the query string — RFC 9449 says it must not. Now stripped (the reference `@atproto/oauth-provider` tolerated it; other PDS implementations may not).
- Feed cursors and handles are now percent-encoded in query strings.
- Verification network calls are no longer issued for posts that don't claim a Speakwrite proof (previously every timeline row triggered a proof lookup per author).
- Removed dead `PublishView.swift` (unreferenced legacy compose screen).

## Design rethink — "Signal"

One idea: **the proof is the product**, so the proof got the design budget.

- **Palette**: near-monochrome ink/paper — true black (OLED) in dark mode, warm paper in light. One accent: proof green, now scheme-aware (deep green on paper for contrast, bright green on black). All colors are trait-aware dynamic colors; views no longer need `colorScheme` plumbing (old `Theme.x(scheme)` calls still work as wrappers).
- **Typography**: monospace is reserved for *evidence* — wordmark, handles, hashes, counters. Body text is the system face at 16pt with breathing room.
- **Proof badge → proof sheet**: the verification seal on any post is now tappable and opens a proof detail sheet showing each cryptographic check (content hash, certificate chain, device signature), the SHA-256 hash, the Secure Enclave key ID, and an independent web-verify link. Grey seal = verifying, green = verified, outline = proof unavailable (author's PDS unreachable).
- **Shared `AppHeader`** replaces four copy-pasted headers.
- **Login screen**: hero with the seal, "Prove a human wrote it.", and a three-line how-it-works. PDS-specific error messaging.
- **Compose**: live keystroke counter in the header (the attestation, made visible); violation banner reworded ("Blocked — only keyboard typing can be verified"); Publish button carries the seal.
- **Settings**: new Verification section (how it works, web verifier, bot) and a Data-server status row.

## Feature pass

- **Draft persistence** — compose text survives app restarts (`UserDefaults`, cleared on publish).
- **Verification detail sheet** — see above; the trust story is now inspectable in-app.
- **PDS health surfacing** — banner + Settings row.

## What needs a Mac (not possible in this environment)

- Build & run: `xcodebuild -scheme Speakwrite -destination 'platform=iOS Simulator,name=iPhone 16'`
- **Re-record snapshot tests** — the UI changed intentionally: set `isRecording = true` in `SnapshotTests.setUp()`, run once, set back.
- Maestro flows: `login_flow.yaml` was updated to match the new login UI (it was already drifted from the old one).
