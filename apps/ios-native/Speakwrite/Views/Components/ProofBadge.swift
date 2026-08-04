import SwiftUI

// MARK: - Verification Badge

/// Seal shown next to an author's name on a Speakwrite post.
/// Grey while verifying, green when the cryptographic proof checks out,
/// orange when a post claims to be verified but its proof can't be confirmed.
/// Tap to open the proof detail sheet.
struct VerificationBadge: View {
    let status: VerificationStatus
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        switch status {
        case .verified:
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.proofVerified)
        case .verifying:
            Image(systemName: "checkmark.seal")
                .font(.system(size: 12))
                .foregroundStyle(Theme.proofPending)
        case .failed:
            Image(systemName: "exclamationmark.seal")
                .font(.system(size: 12))
                .foregroundStyle(Theme.proofFailed)
        case .unverified:
            EmptyView()
        }
    }
}

// MARK: - Proof Detail Sheet

/// Explains what a Speakwrite proof is and shows this post's verification
/// result step by step. The proof is the product — it deserves more than a
/// 12pt icon.
struct ProofDetailSheet: View {
    let status: VerificationStatus
    let authorHandle: String
    let postUri: String
    var onRetry: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private var rkey: String? {
        postUri.components(separatedBy: "/").last
    }

    private var webVerifyURL: URL? {
        guard let rkey else { return nil }
        return URL(string: "https://www.speakwrite.io/verify/\(authorHandle)/\(rkey)")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.xl) {
                    // Status header
                    HStack(spacing: Theme.md) {
                        statusIcon
                            .font(.system(size: 34))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(statusTitle)
                                .font(Theme.monoHeadline)
                                .foregroundStyle(Theme.textPrimary(colorScheme))
                            Text("@\(authorHandle)")
                                .font(Theme.mono)
                                .foregroundStyle(Theme.textSecondary(colorScheme))
                        }
                    }

                    if case .failed(let reason) = status {
                        Text(reason)
                            .font(Theme.monoCaption)
                            .foregroundStyle(Theme.proofFailed)
                            .padding(Theme.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.radiusSm)
                                    .fill(Theme.proofFailed.opacity(0.1))
                            )
                    }

                    // What gets verified
                    VStack(alignment: .leading, spacing: Theme.md) {
                        checkRow(
                            icon: "number",
                            title: "Content hash",
                            detail: "The post text (and any media) is hashed with SHA-256 and compared to the hash the author's device signed."
                        )
                        checkRow(
                            icon: "cpu",
                            title: "Genuine Apple device",
                            detail: "The App Attest certificate chain is validated against Apple's Root CA — the signing key lives in the Secure Enclave."
                        )
                        checkRow(
                            icon: "signature",
                            title: "Hardware signature",
                            detail: "A P-256 ECDSA assertion over the content hash proves this exact content was signed on that device."
                        )
                        checkRow(
                            icon: "keyboard",
                            title: "Typed by hand",
                            detail: "Speakwrite blocks paste, dictation, autocorrect, and hardware keyboards while composing."
                        )
                    }
                    .padding(Theme.lg)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusMd)
                            .fill(Theme.surface(colorScheme))
                    )

                    Text("Verification runs entirely on this device — no Speakwrite server is involved. The proof record lives in the author's own AT Protocol repository.")
                        .font(Theme.monoCaption)
                        .foregroundStyle(Theme.textTertiary(colorScheme))

                    // Actions
                    VStack(spacing: Theme.md) {
                        if let webVerifyURL {
                            Link(destination: webVerifyURL) {
                                Label("Verify independently on the web", systemImage: "safari")
                                    .font(Theme.monoBold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Theme.md)
                            }
                            .buttonStyle(.bordered)
                            .tint(Theme.accent)
                        }

                        if case .failed = status, let onRetry {
                            Button {
                                onRetry()
                                dismiss()
                            } label: {
                                Label("Retry verification", systemImage: "arrow.clockwise")
                                    .font(Theme.monoBold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Theme.md)
                            }
                            .buttonStyle(.bordered)
                            .tint(Theme.warning)
                        }
                    }
                }
                .padding(Theme.xl)
            }
            .background(Theme.background(colorScheme))
            .navigationTitle("Proof")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.monoBold)
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var statusIcon: some View {
        Group {
            switch status {
            case .verified:
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.proofVerified)
            case .verifying:
                ProgressView()
                    .tint(Theme.proofPending)
            case .failed:
                Image(systemName: "exclamationmark.seal.fill")
                    .foregroundStyle(Theme.proofFailed)
            case .unverified:
                Image(systemName: "seal")
                    .foregroundStyle(Theme.proofPending)
            }
        }
    }

    private var statusTitle: String {
        switch status {
        case .verified: return "Human verified"
        case .verifying: return "Verifying…"
        case .failed: return "Proof not confirmed"
        case .unverified: return "No proof"
        }
    }

    private func checkRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Theme.md) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(status == .verified ? Theme.proofVerified : Theme.textSecondary(colorScheme))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.monoBold)
                    .foregroundStyle(Theme.textPrimary(colorScheme))
                Text(detail)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.textSecondary(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#if DEBUG
#Preview("Verified") {
    ProofDetailSheet(
        status: .verified,
        authorHandle: "alice.bsky.social",
        postUri: "at://did:plc:abc/app.bsky.feed.post/3abc123"
    )
}

#Preview("Failed") {
    ProofDetailSheet(
        status: .failed("Failed to fetch proofs: the author's server is unreachable."),
        authorHandle: "alice.bsky.social",
        postUri: "at://did:plc:abc/app.bsky.feed.post/3abc123",
        onRetry: {}
    )
}
#endif
