import SwiftUI

// MARK: - App Header

/// Shared header used across all tabs: avatar → profile, wordmark, optional trailing control.
struct AppHeader<Trailing: View>: View {
    let onAvatarTap: () -> Void
    var seal: Bool = false
    @ViewBuilder var trailing: () -> Trailing

    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        HStack(spacing: Theme.sm) {
            AvatarButton(
                avatarURL: viewModel.myProfile?.avatar,
                handle: viewModel.atproto.handle,
                action: onAvatarTap
            )
            Text("speakwrite")
                .font(Theme.monoTitle)
                .foregroundStyle(Theme.accent)
            if seal {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.accent)
                    .font(.system(size: 14))
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, Theme.lg)
        .padding(.vertical, Theme.sm)
    }
}

extension AppHeader where Trailing == EmptyView {
    init(onAvatarTap: @escaping () -> Void, seal: Bool = false) {
        self.init(onAvatarTap: onAvatarTap, seal: seal, trailing: { EmptyView() })
    }
}

// MARK: - PDS Status Banner

/// Shown when the user's own data server stops responding — without this,
/// a dead PDS looks like a broken app.
struct PDSStatusBanner: View {
    var body: some View {
        HStack(spacing: Theme.sm) {
            Image(systemName: "bolt.horizontal.circle")
                .font(.system(size: 14, weight: .semibold))
            Text("Your data server isn't responding — showing public feeds")
                .font(.system(size: 13, weight: .medium))
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.warning)
        .padding(.horizontal, Theme.lg)
        .padding(.vertical, Theme.sm)
        .frame(maxWidth: .infinity)
        .background(Theme.warning.opacity(0.12))
    }
}

// MARK: - Proof Badge

/// The verification seal shown next to an author's name. Tappable where a
/// report is available — opens the proof detail sheet.
struct ProofBadge: View {
    let status: VerificationStatus

    var body: some View {
        switch status {
        case .verified:
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.verified)
        case .verifying:
            Image(systemName: "checkmark.seal")
                .font(.system(size: 12))
                .foregroundStyle(Theme.tertiaryText)
        case .unavailable:
            Image(systemName: "seal")
                .font(.system(size: 12))
                .foregroundStyle(Theme.tertiaryText)
        case .failed, .unverified:
            EmptyView()
        }
    }
}

// MARK: - Verification Detail Sheet

/// The proof, made visible: what was checked, what the evidence is, and a link
/// to verify independently outside the app.
struct VerificationDetailSheet: View {
    let authorHandle: String
    let postUri: String
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    private var report: VerificationReport? {
        viewModel.verification.report(for: postUri)
    }

    private var status: VerificationStatus {
        report?.status ?? .unverified
    }

    private var webVerifyURL: URL? {
        guard let rkey = postUri.components(separatedBy: "/").last else { return nil }
        return URL(string: "https://www.speakwrite.io/verify/\(authorHandle)/\(rkey)")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.xl) {
                    statusHeader

                    if let report, !report.checks.isEmpty {
                        checksSection(report.checks)
                    }

                    if let report, let hash = report.contentHash, !hash.isEmpty {
                        evidenceSection(contentHash: hash, keyId: report.keyId)
                    }

                    explainer

                    if let url = webVerifyURL {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "safari")
                                Text("Verify independently on the web")
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(Theme.accent)
                            .padding(Theme.lg)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.radiusMd)
                                    .fill(Theme.accentSubtle)
                            )
                        }
                    }
                }
                .padding(Theme.lg)
            }
            .background(Theme.backgroundColor)
            .navigationTitle("Proof")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: Sections

    private var statusHeader: some View {
        HStack(spacing: Theme.md) {
            Image(systemName: statusIcon)
                .font(.system(size: 34))
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.primaryText)
                Text("@\(authorHandle)")
                    .font(Theme.mono)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private func checksSection(_ checks: [VerificationCheck]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(checks) { check in
                HStack(alignment: .top, spacing: Theme.md) {
                    Image(systemName: check.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(check.passed ? Theme.verified : Theme.error)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(check.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.primaryText)
                        Text(check.detail)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, Theme.sm)

                if check.id != checks.last?.id {
                    Divider().foregroundStyle(Theme.divider)
                }
            }
        }
        .padding(.horizontal, Theme.lg)
        .padding(.vertical, Theme.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMd)
                .fill(Theme.elevatedColor)
        )
    }

    private func evidenceSection(contentHash: String, keyId: String?) -> some View {
        VStack(alignment: .leading, spacing: Theme.sm) {
            Text("EVIDENCE")
                .font(Theme.monoCaption)
                .foregroundStyle(Theme.tertiaryText)

            VStack(alignment: .leading, spacing: Theme.xs) {
                Text("Content hash · SHA-256")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
                Text(contentHash)
                    .font(Theme.monoSmall)
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }

            if let keyId, !keyId.isEmpty {
                VStack(alignment: .leading, spacing: Theme.xs) {
                    Text("Secure Enclave key")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                    Text(keyId)
                        .font(Theme.monoSmall)
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(Theme.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMd)
                .fill(Theme.surfaceColor)
        )
    }

    private var explainer: some View {
        Text(explainerText)
            .font(.system(size: 13))
            .foregroundStyle(Theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Status presentation

    private var statusIcon: String {
        switch status {
        case .verified: return "checkmark.seal.fill"
        case .verifying: return "checkmark.seal"
        case .unavailable: return "seal"
        case .failed: return "xmark.seal"
        case .unverified: return "seal"
        }
    }

    private var statusColor: Color {
        switch status {
        case .verified: return Theme.verified
        case .verifying, .unavailable, .unverified: return Theme.tertiaryText
        case .failed: return Theme.error
        }
    }

    private var statusTitle: String {
        switch status {
        case .verified: return "Typed by a human"
        case .verifying: return "Verifying…"
        case .unavailable: return "Proof unavailable"
        case .failed: return "Not verified"
        case .unverified: return "No proof"
        }
    }

    private var explainerText: String {
        switch status {
        case .verified:
            return "This post carries a cryptographic proof that it was typed on the soft keyboard of a genuine Apple device, signed by that device's Secure Enclave. Verification ran entirely on your device — no server was involved."
        case .verifying:
            return "Fetching the proof record from the author's data server and running the cryptographic checks on your device."
        case .unavailable:
            return "The author's data server didn't respond, so the proof couldn't be fetched. Pull to refresh to try again."
        case .failed:
            return "No valid Speakwrite proof was found for this post. It may have been posted from another app, or the proof doesn't match the content."
        case .unverified:
            return "This post hasn't been checked yet."
        }
    }
}

#if DEBUG
#Preview("Proof Badges") {
    HStack(spacing: 16) {
        ProofBadge(status: .verified)
        ProofBadge(status: .verifying)
        ProofBadge(status: .unavailable("offline"))
    }
    .padding()
}

#Preview("PDS Banner") {
    PDSStatusBanner()
}
#endif
