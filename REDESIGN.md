# Speakwrite iOS — Redesign & Debug Pass (August 2026)

This document captures the findings and changes from a full review of the iOS app:
why the app "isn't working," what was fixed, how the design direction evolved, and
a proposed feature roadmap.

---

## 1. Diagnosis: why the app isn't working

### Root cause: your PDS is offline

The account `stefans.house` lives on a **self-hosted PDS at `pds.stefans.house`,
and that server is currently unreachable from the public internet** (TLS
connections on 443 are reset; the apex domain times out). Everything
account-related depends on it:

- **Sign-in** — OAuth discovery starts at the PDS's
  `/.well-known/oauth-protected-resource`; a dead PDS means login can't even begin.
- **Following feed, profile, publishing** — all authenticated XRPC calls go to the PDS.
- **Verification of your posts** — readers (app, bot, web verifier) fetch
  `io.speakwrite.proof` records from *your* PDS. While it's down, nobody can verify
  your existing posts.

The rest of the stack checks out healthy (verified live during this review):

| Component | Status |
|---|---|
| speakwrite.io + `/verify` page | ✅ 200 OK |
| OAuth client metadata (`/app/client-metadata.json`) | ✅ valid |
| `api.bsky.app` search for `#speakwrite` | ✅ returning posts |
| `@verify.speakwrite.io` bot account | ✅ live (24 posts) |
| `pds.stefans.house` | ❌ connection reset / timeout |

**Action item (outside this repo):** restart or re-expose the PDS —
check the box/container running it, DNS, and any tunnel/firewall in front of it.

### Aggravating factor: the app hid the failure

Every feed loader swallowed errors with `print(...)`, so a dead PDS produced
stale cached posts and empty screens with no explanation — indistinguishable
from a broken app. Sign-in reported a generic "Sign in failed." This pass makes
failure states first-class (see §3).

## 2. Bug fixes in this pass

### Integrity of the proof itself

1. **Proof record writes could silently fail** — `publishAttestedPost` wrote the
   `io.speakwrite.proof` record with `try?` and discarded the result. On a flaky
   PDS the post published *with* the "Verify a human wrote this" footer but *no
   proof*, so every verifier reports it unverifiable forever. The proof write is
   now mandatory: if it fails, the post is rolled back and the error is shown.
   This is the most likely cause of "posts stopped verifying."
2. **App Attest key/attestation desync after reinstall** — the key ID lived in
   `UserDefaults` (wiped on reinstall) while the attestation object lived in the
   Keychain (survives reinstall). A reinstall paired a fresh key with the old
   attestation, permanently breaking signature verification for all future
   posts. Both now live in the Keychain with the same lifetime, with migration
   for existing installs and a retry path for invalidated keys.
3. **Bot accepted forgeable cert chains (security)** — the bot verified the
   intermediate against Apple's root but only name-checked the leaf
   (`checkIssued` is not a signature check). A self-signed leaf copying Apple's
   intermediate DN would have passed. The leaf's signature is now
   cryptographically verified against the intermediate's public key.

### Publishing & composing

4. **Reply threading broke threads** — replies always set `root = parent`, so
   replying to a reply detached the post from its thread on every AT Protocol
   client. The parent's own `reply.root` is now resolved and threaded correctly.
5. **Silent image-upload failure** — `uploadBlob` returned `{}` on any non-401
   error, publishing posts with broken image embeds. It now retries once
   (refreshing tokens/nonce) and then throws, surfacing the error in compose.
6. **Reply/quote sheets destroyed the compose draft** — their editors routed
   keystrokes through the shared view model, overwriting `postText` and firing
   the violation banner on the wrong screen.
7. **300-char posts failed at publish** — the compose limit was 300, but the
   appended verify footer (~46 chars) pushed posts over Bluesky's 300-grapheme
   limit. The limit is now 254.
8. **"Published ✓" was never visible** — the success state was cleared before
   SwiftUI could render a frame; it now persists until a new draft is started.
9. **The violation banner fired after successful publishes** (counter reset
   was indistinguishable from a violation) — it now only fires on increases.

### Verification pipeline

10. **Verification failures were cached forever** — one transient network blip
    marked a post "failed" for the whole session. Failures now expire after 60s
    and can be retried from the proof sheet.
11. **`did:web` authors could never verify** — proof lookup only resolved DIDs
    via `plc.directory`. `did:web` resolution added.
12. **Proof lookups hammered every author** — the full proof pipeline (PLC
    resolve + `listRecords`) ran for *every* timeline post. Now gated to posts
    that actually claim a proof.
13. **Verification broke past 100 posts** — proof lookup fetched a single
    `listRecords` page. It now paginates (up to 1,000 records).
14. **5xx from an author's PDS read as "no proof record"** — server errors now
    count as transient (retryable) instead of a definitive verdict.

### Feeds & UI state

15. **Feed errors were invisible** — every loader swallowed errors into
    `print`, rendering "No posts" / stale cache with no explanation (see §3,
    status banners).
16. **Stale cached posts pinned to the top of the Verified feed forever** —
    the optimistic-insert merge treated every cache-only post as "pending
    indexing." The grace window is now 15 minutes.
17. **Pagination could duplicate posts and spin forever** — no in-flight guard,
    no URI dedupe (duplicate IDs are undefined behavior in `ForEach`), and an
    unchanged cursor retriggered indefinitely. All three feeds now guard,
    dedupe, and terminate.
18. **Tapping a video with a malformed URL crashed** (force-unwrap); recycled
    image views could show the previous post's photo. Both fixed.
19. **Profile/avatar never loaded after a fresh sign-in** — profile + feeds now
    load on every login transition, not just on app launch.
20. **Sign-out leaked the previous account's feeds** — the on-disk `FeedCache`
    survived logout and rendered under the next account. Now cleared.
21. **A profile-header fetch blip hid successfully loaded posts** — the
    full-screen error now only shows when there is nothing to render.
22. **Camera errors in the reply sheet were silent** — now surfaced.
23. **Sign-in errors were generic** — a dead/unreachable PDS now reports
    "Can't reach your server (host)…" instead of "Sign in failed."
24. Removed dead code: `PublishView.swift`, `replyToPost`, `quotePost`.

### Bot & web verifier

25. **Bot notification backlog grew forever** — notifications were only marked
    seen when a mention was found, so likes/follows accumulated unread and every
    30s poll re-walked the entire backlog (eventually rate-limiting the bot into
    silence). Non-mention notifications are now marked seen too.
26. **Bot dedup checked the wrong thread node** — it looked for its reply under
    the *target post*, but it replies under the *mention*; restarts produced
    duplicate replies. Now checks the mention.
27. **Bot proof lookup walked history oldest-first** (`reverse=true`), costing
    dozens of sequential PDS round trips for prolific authors and missing recent
    posts past the page cap. Now newest-first — one page in the common case.
28. **Web verifier rejected AT-URI input** — `at://did:…` was passed to
    `resolveHandle` as if it were a handle. DIDs are now used directly.

### Known issues, deliberately deferred

- **Swipe typing (QuickPath) is blocked** by the multi-character-insert
  heuristic that also blocks dictation. Distinguishing the two needs on-device
  work; today's behavior silently drops swiped words. Needs a product decision
  (allow swipe = weaken the dictation guard) plus device testing.
- The dual text-write path in `InputRestrictedEditor` (delegate hop + coordinator)
  can race and snap the caret to the end; needs on-device reproduction
  (`.maestro/regression_cursor_jump.yaml`).
- Engagement counts on rows only sync on row appearance, so pull-to-refresh
  doesn't update like state on unchanged rows.
- `String`-typed navigation carries both DIDs and handles into `ProfileView`;
  tapping your own @mention shows a Follow button.
- Neither the bot nor the in-app verifier checks the attestation nonce
  extension, AAGUID, `credentialId == keyId`, or rpIdHash — only the web
  verifier does. Aligning all three verifiers is protocol work worth its own pass.
- iPad share-sheet crash (no popover anchor) in `PostRow`/`PostDetailView`.

## 3. Design pass

Design thesis: **the proof is the product**. The old UI treated verification as
a 12pt icon; the new pass makes the proof visible, tappable, and honest about
failure.

### Shipped in this pass

- **Proof detail sheet** — tapping any verification seal opens a sheet that
  shows the verification result, explains the four guarantees (content hash,
  genuine device, hardware signature, typed-by-hand), links to independent web
  verification, and offers retry on failure.
- **Honest badge states** — verified (green seal), verifying (grey), and now
  **proof-not-confirmed (orange `exclamationmark.seal`)** for posts that claim
  a proof that doesn't check out. An authenticity app shouldn't render
  unverifiable claims identically to unclaimed posts.
- **Integrity HUD in compose** — a live strip above the toolbar showing
  keystrokes counted, active restrictions ("paste · dictation · autocorrect off"),
  and violations blocked. The proof ritual is now visible while you type,
  not just asserted after you publish.
- **Degraded-network banners** — every feed shows a slim warning banner
  ("Can't reach your server (pds.stefans.house)" / "No internet connection")
  with a retry action whenever content may be stale, instead of failing silently.
- **Clearer violation banner copy** in compose.
- Theme: semantic proof colors (`proofVerified` / `proofPending` / `proofFailed`)
  and a `warning` token.

### Proposed next (not in this pass)

- **Merge the Feed/Verified tabs** into one Home with Following / For You /
  Verified pills, freeing a tab slot for **Notifications**
  (`app.bsky.notification.listNotifications`) — the biggest missing social loop.
- **Profile proof stats** — "87% of posts human-verified" on profile pages;
  a per-author trust signal no other client can render.
- **Draft persistence** — compose text survives app restarts (typing 300
  characters on a phone is an investment; losing it to a crash is brutal).
- **Verified-only mode** — a reader toggle that filters every feed to
  proof-carrying posts.

## 4. Feature / protocol roadmap ideas

- **Proof caching by post** (rather than per-author `listRecords`) once volume
  grows; consider a `getRecord` fast path using the post rkey convention.
- **Offline PDS resilience** — queue posts composed while the PDS is down and
  publish when it recovers (keystroke restrictions make re-typing costly, so
  queuing matters more here than in a normal client).
- **Android** — Play Integrity API is the analogue of App Attest; the proof
  lexicon already carries `appId`, so a `platform` field is the main schema change.
- **Lexicon publication** — publish the `io.speakwrite.proof` lexicon schema
  record so other clients can render badges natively.
- **Bot** — reply latency SLO + a "why did this fail" breakdown in bot replies,
  matching the app's new per-check explanation.

## 5. Verification of this pass

No Xcode/simulator is available in this environment, so the Swift changes were
made conservatively (small, isolated diffs; new code in new files) and reviewed
statically. The three new views (`StatusBanner`, `ProofBadge`, `IntegrityHUD`)
are registered in `project.pbxproj`. Build + snapshot tests should be run in
Xcode before TestFlight: `xcodebuild test -scheme Speakwrite -destination
'platform=iOS Simulator,name=iPhone 16'`.
