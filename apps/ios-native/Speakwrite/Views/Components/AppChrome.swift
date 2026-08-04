import SwiftUI

// MARK: - App Header
//
// Shared chrome across the four tabs: avatar (→ profile), the wordmark,
// and an optional trailing action. The wordmark is serif ink — the brand is
// "human writing"; the seal glyph carries the crypto identity.

struct AppHeader<Trailing: View>: View {
    var showSeal: Bool = false
    var onAvatarTap: () -> Void
    @ViewBuilder var trailing: Trailing

    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        HStack(spacing: Theme.sm) {
            AvatarButton(
                avatarURL: viewModel.myProfile?.avatar,
                handle: viewModel.atproto.handle,
                action: onAvatarTap
            )

            HStack(spacing: Theme.xs) {
                Text("Speakwrite")
                    .font(.system(.title3, design: .serif).weight(.bold))
                    .foregroundStyle(Theme.ink)
                if showSeal {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                }
            }

            Spacer()

            trailing
        }
        .padding(.horizontal, Theme.lg)
        .padding(.vertical, Theme.sm)
    }
}

extension AppHeader where Trailing == EmptyView {
    init(showSeal: Bool = false, onAvatarTap: @escaping () -> Void) {
        self.init(showSeal: showSeal, onAvatarTap: onAvatarTap, trailing: { EmptyView() })
    }
}

// MARK: - Feed Status Banner
//
// Surfaces load failures (e.g. the user's PDS is unreachable) instead of
// silently showing stale content.

struct FeedStatusBanner: View {
    let message: String
    var onRetry: (() -> Void)?

    var body: some View {
        HStack(spacing: Theme.sm) {
            Image(systemName: "wifi.exclamationmark")
                .font(.footnote)
                .foregroundStyle(Theme.warning)

            Text(message)
                .font(Theme.subhead)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: Theme.sm)

            if let onRetry {
                Button("Retry", action: onRetry)
                    .font(Theme.subhead.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, Theme.lg)
        .padding(.vertical, Theme.sm)
        .background(Theme.surfaceColor)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Success Toast

struct SuccessToast: View {
    let message: String

    var body: some View {
        HStack(spacing: Theme.sm) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Theme.accent)
            Text(message)
                .font(Theme.subhead.weight(.medium))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, Theme.lg)
        .padding(.vertical, Theme.md)
        .background(
            Capsule()
                .fill(Theme.surfaceElevatedColor)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Seal Badge
//
// The verification mark. Tappable wherever it appears — tapping opens the
// proof explanation so the product's core concept is discoverable.

struct SealBadge: View {
    let status: VerificationStatus
    var action: (() -> Void)?

    var body: some View {
        Group {
            switch status {
            case .verified:
                badgeImage("checkmark.seal.fill", color: Theme.accent)
                    .accessibilityLabel("Human verified. Tap for proof details.")
            case .verifying:
                badgeImage("checkmark.seal", color: Theme.inkTertiary)
                    .accessibilityLabel("Verifying proof")
            default:
                badgeImage("seal", color: Theme.inkTertiary.opacity(0.6))
                    .accessibilityLabel("Proof unavailable. Tap for details.")
            }
        }
    }

    @ViewBuilder
    private func badgeImage(_ name: String, color: Color) -> some View {
        if let action {
            Button(action: action) {
                Image(systemName: name)
                    .font(.caption)
                    .foregroundStyle(color)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Image(systemName: name)
                .font(.caption)
                .foregroundStyle(color)
        }
    }
}
