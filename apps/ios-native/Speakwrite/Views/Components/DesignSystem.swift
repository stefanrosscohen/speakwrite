import SwiftUI

// MARK: - Themed Divider
//
// `Divider().foregroundStyle(...)` does not tint a Divider, so the app's
// separators were rendering in the system default color. This draws a real
// hairline in the theme color.

struct ThemedDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.separator)
            .frame(height: 0.5)
    }
}

// MARK: - Tab Header
//
// The monospaced brand header shared by every tab. Title on the left,
// optional action buttons on the right.

struct TabHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: Theme.md) {
            Text(title)
                .font(Theme.monoTitle)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            trailing
        }
        .padding(.horizontal, Theme.lg)
        .padding(.vertical, Theme.md)
    }
}

// MARK: - Follow Button
//
// One follow control for the whole app: capsule, accent fill when not
// following, outline when following. Unfollow asks for confirmation.

struct FollowButton: View {
    let isFollowing: Bool
    let isWorking: Bool
    let action: () -> Void

    @State private var showUnfollowConfirm = false

    var body: some View {
        Button {
            if isFollowing {
                showUnfollowConfirm = true
            } else {
                action()
            }
        } label: {
            HStack(spacing: Theme.xs) {
                if isWorking {
                    ProgressView()
                        .controlSize(.mini)
                } else if isFollowing {
                    Image(systemName: "checkmark")
                        .font(Theme.caption.weight(.bold))
                }
                Text(isFollowing ? "Following" : "Follow")
                    .font(Theme.caption.weight(.bold))
            }
            .foregroundStyle(isFollowing ? Theme.textSecondary : Theme.onAccent)
            .padding(.horizontal, Theme.md)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isFollowing ? Theme.surface : Theme.accent)
            )
            .overlay(
                Capsule().strokeBorder(
                    isFollowing ? Theme.separator : Color.clear, lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .accessibilityLabel(isFollowing ? "Unfollow" : "Follow")
        .confirmationDialog("Unfollow?", isPresented: $showUnfollowConfirm, titleVisibility: .visible) {
            Button("Unfollow", role: .destructive) { action() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Verification Badge
//
// The seal next to an author name. Icon + color, with an accessibility
// label so the state isn't conveyed by color alone.

struct VerificationBadge: View {
    let status: VerificationStatus

    var body: some View {
        switch status {
        case .verified:
            Image(systemName: "checkmark.seal.fill")
                .font(Theme.caption)
                .foregroundStyle(Theme.verified)
                .accessibilityLabel("Verified human-typed post")
        case .verifying:
            Image(systemName: "checkmark.seal")
                .font(Theme.caption)
                .foregroundStyle(Theme.verifying)
                .accessibilityLabel("Verifying")
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(Theme.caption)
                .foregroundStyle(Theme.verificationFailed)
                .accessibilityLabel("Verification failed")
        case .unverified:
            EmptyView()
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: Theme.md) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(Theme.textTertiary)
            Text(title)
                .font(Theme.monoHeadline)
                .foregroundStyle(Theme.textSecondary)
            if let subtitle {
                Text(subtitle)
                    .font(Theme.subhead)
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.xxxl * 2)
        .padding(.horizontal, Theme.xxl)
    }
}

// MARK: - Error State

struct ErrorStateView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: Theme.md) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(Theme.textTertiary)
            Text("Couldn't load")
                .font(Theme.monoHeadline)
                .foregroundStyle(Theme.textSecondary)
            Text(message)
                .font(Theme.subhead)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            Button(action: retry) {
                Text("Retry")
                    .font(Theme.monoBold)
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, Theme.xl)
                    .padding(.vertical, Theme.sm)
                    .background(Capsule().fill(Theme.accent))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.xxxl * 2)
        .padding(.horizontal, Theme.xxl)
    }
}

// MARK: - Profile Stat
//
// One stat style for both profile screens: monospaced count, abbreviated,
// with a quiet label.

struct ProfileStat: View {
    let count: Int
    let label: String

    var body: some View {
        HStack(spacing: Theme.xs) {
            Text(formatCount(count))
                .font(Theme.monoStat)
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(Theme.subhead)
                .foregroundStyle(Theme.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Components") {
    VStack(spacing: 24) {
        ThemedDivider()
        TabHeader("speakwrite") {
            Image(systemName: "magnifyingglass")
        }
        HStack {
            FollowButton(isFollowing: false, isWorking: false) {}
            FollowButton(isFollowing: true, isWorking: false) {}
        }
        HStack(spacing: 16) {
            VerificationBadge(status: .verified)
            VerificationBadge(status: .verifying)
            VerificationBadge(status: .failed("nope"))
        }
        HStack(spacing: 16) {
            ProfileStat(count: 1234, label: "followers")
            ProfileStat(count: 87, label: "following")
        }
        ErrorStateView(message: "The network request timed out.") {}
    }
    .padding()
    .background(Theme.background)
}
