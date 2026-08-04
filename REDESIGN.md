# Speakwrite iOS — Redesign, Feature Pass & Debug (August 2026)

This document records the full pass over the iOS app: why it wasn't working,
what was fixed, the new design language, and the feature roadmap.

---

## 1. Why the app "isn't working" — diagnosis

### The immediate cause is infrastructure, not code

**`pds.stefans.house` (137.184.138.83) is down.** HTTPS connections are reset
and port 80 times out. The `stefans.house` account lives on that self-hosted
PDS, so every authenticated call — following feed, profile, publishing, token
refresh — fails. The app swallowed those errors silently and just looked dead.

**Action required outside this repo: restart / repair the PDS server.**
Everything else on the network side checks out:

| Surface | Status |
|---|---|
| `api.bsky.app` searchPosts / getFeed (feed sources) | ✅ healthy, `tags:["speakwrite"]` indexed |
| `www.speakwrite.io` + `/app/client-metadata.json` (OAuth) | ✅ live, correct |
| `/verify/{handle}/{rkey}` deep links | ✅ works via the 404.html SPA redirect |
| `@verify.speakwrite.io` bot account | ✅ resolves |
| `pds.stefans.house` | ❌ **connection reset — server down** |

The app now degrades gracefully when a PDS is unreachable (see below) instead
of failing silently, but publishing and the following feed fundamentally
require the PDS to be up.

### Code bugs that compounded it

1. **Session-killing refresh race** — 4 concurrent requests at launch each
   triggered their own token refresh. AT Protocol refresh tokens are
   single-use, so the losers got `invalid_grant` → forced logout.
2. **Silent feed failures** — every load error was `print()`-ed and swallowed.
3. **CI red since February** — SwiftLint `force_unwrapping: error` against a
   codebase full of static `URL(string:)!`, plus snapshot/E2E flakiness.

---

## 2. Fixes shipped in this pass

### Auth & session (ATProtoService)
- **Single-flight token refresh** — concurrent 401s await one shared refresh.
- **Proactive refresh** — token expiry (`expires_in`) is tracked and refresh
  happens before requests instead of burning a guaranteed 401.
- Token requests are now **form-encoded** (RFC 6749) instead of JSON —
  bsky.social tolerated JSON; third-party/self-hosted PDSes may not.
- OAuth callback now **verifies the `state` parameter** (CSRF).
- `uploadBlob` routed through the authenticated-request path → photo publishing
  now survives token expiry (nonce retry + refresh).
- **Public AppView fallback** for reads (discover feed, profiles, threads,
  author feeds) when the PDS is unreachable — the app stays usable read-only
  with a visible "Can't reach your server (PDS)" banner and retry.

### Verification integrity (the product guarantee)
- **The verifier was forgeable**: it never checked `rpIdHash`, `appId`,
  `keyId`↔leaf-key binding, the attestation nonce, or the AAGUID. Any iOS
  developer could have attested their own key and earned a green seal. All
  checks now mirror the web verifier: rpIdHash = SHA-256 of
  `TEAMID.io.speakwrite.app`, keyId = SHA-256(leaf public key), credentialId
  match, Apple's nonce cert extension (OID 1.2.840.113635.100.8.2), production
  AAGUID only, assertion counter ≥ 1.
- **CBOR decoder hardened** — a malicious proof record could previously crash
  every app that scrolled past it (trapping length conversions, unbounded
  `reserveCapacity`, offset corruption on float values). Now total and
  non-trapping with a nesting-depth cap.
- **Reinstall no longer bricks verification** — attestation blobs are keyed by
  keyId; stale blobs from a previous install are discarded; `DCError.invalidKey`
  (device migration) triggers one-shot re-provisioning.
- **Transient failures are no longer cached as permanent** — a PDS 429/5xx used
  to mark a legitimately verified post "failed" for the whole session. Fetch
  errors now retry with a 30s cooldown; pagination follows the cursor (up to
  500 proofs); `did:web:` authors can now verify; PLC lookups are cached.
- **Verification only runs for Speakwrite-tagged posts** — it previously ran
  (twice) for every post by every author while scrolling, hammering
  plc.directory and strangers' PDSes.

### Input restriction (the other half of the guarantee)
- **Dictation actually blocked** — dictation streamed results through the
  marked-text (IME) path and bypassed the multi-char check. Now:
  `insertDictationResult` is swallowed, and dictation input mode is refused at
  both `insertText` and `setMarkedText`.
- **Hardware keyboards actually blocked** — key presses were "consumed" but the
  characters still arrived via the text-input system (while *also* counting
  violations against the user). Characters arriving right after a hardware key
  press are now dropped.
- **CJK/IME typing fixed** — attributed-text rewrites no longer cancel active
  composition; composition commits are allowed and not counted as violations.
- Keychain items moved to `AfterFirstUnlockThisDeviceOnly`; keychain write
  failures are logged instead of silently ignored.

### UX & state bugs
- Sign-out now clears **everything**: draft, captured media, keystroke
  counters, engagement state, verification cache, selected tab (previously the
  next account inherited the previous user's draft and camera photos).
- Like/repost/follow state moved from per-row `@State` (reverted on scroll,
  caused duplicate like records) into the shared view model keyed by URI.
- Publish success is now visible — "Published & sealed" toast on the Verified
  feed (the old success state was dead code that never rendered).
- Feed loads are reentrancy-guarded (tab switches used to fire duplicate
  concurrent loads that clobbered cursors).
- Video capture: heavy work moved off the main thread (was a multi-second
  freeze), `.mov` is remuxed to real MP4 so the hash matches the uploaded
  bytes, thumbnails aspect-fill instead of stretching, temp files cleaned up.
- Crash fix: force-unwrapped video playlist URL; image loading now cached +
  downsampled; reply/quote sheets scroll on small screens; placeholder now
  renders in reply/quote composers; mention taps work in the search stack;
  44pt tap targets on media remove buttons.

---

## 3. The redesign — "Signed ink"

The old identity was terminal/hacker: neon green mono wordmark on near-black.
It undersold the idea. The product is about **the human hand behind the words**
— so the new language pairs editorial warmth with cryptographic precision:

- **Post text is serif** (New York), in the feed and in the composer. The
  writing is the artifact.
- **Chrome is the system sans** via Dynamic Type text styles — the entire app
  now scales with accessibility settings (previously every font was a fixed
  pixel size).
- **Monospace is reserved for proof surfaces** — hashes, the keystroke
  counter, seal details. It's the signature, not the voice.
- **One accent: seal green** — deep emerald `#127A44` on warm paper in light
  mode (≈5.4:1 contrast; the old neon green was ~1.9:1 as text), mint
  `#34D07C` on ink in dark mode. All colors are now adaptive (no more manual
  `colorScheme` plumbing).
- **The seal explains itself** — tapping the verification badge on any post
  opens a Proof sheet: what the status means, the three checks (typed by hand,
  signed by the device, verified client-side), what it *doesn't* prove, and an
  independent web-verification link. The product's core concept was previously
  never explained anywhere in the UI.
- Login, feeds, compose, and settings share the new chrome (serif wordmark
  header, styled fields, accent-filled buttons with proper contrast, honest
  violation messaging instead of "Naughty naughty").

## 4. Feature pass — shipped

- **Proof detail sheet** (tap any seal) — verification as a first-class,
  legible object.
- **Draft persistence** — on a paste-blocked, type-only editor, losing a draft
  is brutal. Drafts survive app restarts; cleared on publish/clear/sign-out.
- **Keystroke counter in the publish bar** — "n keys" — quiet evidence of the
  work being sealed.
- **PDS-outage banner + read-only degradation** — the app tells you your
  server is down instead of pretending the network is empty.
- **Publish confirmation** — "Published & sealed" toast on the Verified feed.

## 5. Feature roadmap — proposed next

1. **Notifications tab** (`app.bsky.notification.listNotifications`) — replies,
   likes, mentions, follows. The biggest functional gap vs. any Bluesky client;
   also the retention loop.
2. **Verified-only filter** on the Following feed — "show me only posts by
   humans" is the product's whole pitch, one toggle away.
3. **Proof-strength levels** — text-only vs. text+live-media proofs surfaced
   differently (the composite hash already distinguishes them).
4. **Onboarding** — a 3-screen first-run explaining the keyboard restriction
   and the camera-only media rule *before* the user hits them as errors.
5. **Writing stats** — words typed, streaks, proofs published; mono aesthetic,
   shareable card.
6. **Verify-anything** — paste any Bluesky post URL into the app to run
   verification (the bot and website can; the app should too).
7. **PDS health surface** in Settings for self-hosters — reachability + last
   successful refresh, since a dead PDS looks like a dead app.

## 6. Known limitations / notes

- Snapshot & Maestro CI jobs need a re-record pass against the new UI; the
  lint job should now pass (force-unwrap downgraded to warning). This branch
  changes the UI substantially, so old snapshots are invalid by design.
- The iOS verifier now rejects *sandbox* App Attest attestations (dev builds)
  — the website accepts them; posts proven from a development build verify on
  the web but not in the released app.
- Counter monotonicity across posts can't be enforced in a stateless feed
  verifier; counter ≥ 1 is required.
