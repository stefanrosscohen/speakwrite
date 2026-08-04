# Speakwrite iOS

iOS native SwiftUI application for AT Protocol/Bluesky with human-verified posting via Apple App Attest.

## Project Details

- **Bundle ID:** io.speakwrite.app
- **Minimum iOS:** 17.0
- **Swift:** 5.0
- **Third-party dependencies:** None (only Apple frameworks: CryptoKit, DeviceCheck, AuthenticationServices)

## Build & Test

```bash
# Build
xcodebuild -scheme Speakwrite -destination 'platform=iOS Simulator,name=iPhone 16'

# Unit tests
xcodebuild test -scheme Speakwrite -destination 'platform=iOS Simulator,name=iPhone 16'

# Maestro E2E tests
maestro test .maestro/
```

## Architecture

Single `AppViewModel` (`@Observable`) serves as global state, injected via `.environment()`.

### Key Directories

- `Views/` — Top-level screens
- `Views/Components/` — Reusable UI components
- `ViewModels/` — AppViewModel
- `Services/` — Networking, attestation, verification

### Key Services

- **ATProtoService** — OAuth (PKCE + DPoP) and XRPC API calls. Uses a shared 15s-timeout `URLSession`; authenticated reads fall back to the public AppView (`api.bsky.app`) when the user's PDS is unreachable, and expose `pdsUnreachable` for UI banners
- **DeviceAttestation** — Apple App Attest integration
- **VerificationService** — Client-side proof verification; produces a `VerificationReport` (per-check results) shown in the proof detail sheet. Transient failures are `.unavailable` and retried on feed refresh
- **KeystrokeCapture** — Input-restricted UITextView (soft keyboard only)

### Navigation

`TabView` with 4 tabs (Feed, Verified, Compose, Settings), each with its own `NavigationStack`.

### Data Types

- `VerifiedPost` / `TimelinePost` — Post models (both conform to `PostDisplayable`)
- `PostAuthor`, `ProfileViewDetailed`, `PostNavigation`, `ThreadReply`

## Theme System

`Theme` enum: spacing tokens (xs/sm/md/lg/xl), typography, and trait-aware
dynamic colors (`Theme.primaryText`, `Theme.accent`, `Theme.onAccent`, …) that
adapt to light/dark automatically — no `colorScheme` plumbing needed. The
legacy `Theme.x(scheme)` functions still exist as wrappers. Monospace type is
reserved for evidence (wordmark, handles, hashes, counters). See `REDESIGN.md`
for the design language.

Shared chrome lives in `Views/Components/ProofComponents.swift`: `AppHeader`,
`ProofBadge`, `VerificationDetailSheet`, `PDSStatusBanner`.

## Testing

- **Unit tests:** `SpeakwriteTests/` — Theme, utilities, data transformations
- **Snapshot tests:** `SpeakwriteTests/SnapshotTests.swift` — requires swift-snapshot-testing SPM package
- **E2E tests:** `.maestro/` — Maestro YAML flows for user journeys
- **Previews:** All views have `#Preview` blocks using `PreviewHelpers.swift` mock data
