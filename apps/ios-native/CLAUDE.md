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

- **ATProtoService** — OAuth (PKCE + DPoP) and XRPC API calls
- **DeviceAttestation** — Apple App Attest integration
- **VerificationService** — Human-verified posting flow
- **KeystrokeCapture** — Typing behavior for authenticity signals

### Navigation

`TabView` with 4 tabs (Home, Verified, Activity, Profile), each with its own `NavigationStack`. Compose is a full-screen modal presented from a floating action button available on every tab (`viewModel.showCompose`). Settings is pushed from the Profile tab's gear button.

### Data Types

- `VerifiedPost` / `TimelinePost` — Post models (both conform to `PostDisplayable`)
- `PostAuthor`, `ProfileViewDetailed`, `PostNavigation`, `ThreadReply`

## Theme System

`Theme` enum: spacing tokens (xs/sm/md/lg/xl), Dynamic Type–aware typography (sans for post content, monospaced for the app's own voice), and dynamic colors (trait-collection driven — views never read `colorScheme` to pick a color). `Theme.onAccent` is the only foreground used on accent fills. Shared UI primitives (ThemedDivider, TabHeader, FollowButton, VerificationBadge, EmptyStateView, ErrorStateView, ProfileStat) live in `Views/Components/DesignSystem.swift`; `formatCount` is the one count abbreviator.

## Testing

- **Unit tests:** `SpeakwriteTests/` — Theme, utilities, data transformations
- **Snapshot tests:** `SpeakwriteTests/SnapshotTests.swift` — requires swift-snapshot-testing SPM package
- **E2E tests:** `.maestro/` — Maestro YAML flows for user journeys
- **Previews:** All views have `#Preview` blocks using `PreviewHelpers.swift` mock data
