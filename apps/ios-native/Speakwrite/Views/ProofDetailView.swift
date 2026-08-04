import SwiftUI

/// Explains the verification seal — shown when a user taps the seal on any post.
///
/// The seal is the product's core concept and was previously unexplained
/// anywhere in the UI. This sheet says what the current status means, how the
/// proof is checked, and links to independent web verification.
struct ProofDetailView: View {
    let status: VerificationStatus
    let authorHandle: String
    let postUri: String

    @Environment(\.dismiss) private var dismiss

    private var rkey: String? {
        postUri.components(separatedBy: "/").last
    }

    private var webVerifyURL: URL? {
        guard let rkey, !rkey.isEmpty else { return nil }
        return URL(string: "https://www.speakwrite.io/verify/\(authorHandle)/\(rkey)")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.xl) {
                    statusHeader

                    Divider().overlay(Theme.hairline)

                    VStack(alignment: .leading, spacing: Theme.lg) {
                        Text("How this works")
                            .font(Theme.headline)
                            .foregroundStyle(Theme.ink)

                        checkRow(
                            icon: "keyboard",
                            title: "Typed by hand",
                            detail: "Speakwrite blocks paste, dictation, autocorrect, and hardware keyboards. Every character was tapped on the screen."
                        )
                        checkRow(
                            icon: "cpu",
                            title: "Signed by the device",
                            detail: "A hardware key in the iPhone's Secure Enclave signs a fingerprint (SHA-256) of the exact text — Apple certifies the key belongs to a real device running the unmodified app."
                        )
                        checkRow(
                            icon: "checkmark.seal",
                            title: "Checked on your device",
                            detail: "Your device fetched the proof from the author's own data server and re-ran the cryptography itself. No Speakwrite server was involved."
                        )
                    }

                    Divider().overlay(Theme.hairline)

                    VStack(alignment: .leading, spacing: Theme.sm) {
                        Text("What it doesn't prove")
                            .font(Theme.headline)
                            .foregroundStyle(Theme.ink)
                        Text("That the ideas are original, or that no AI was consulted. It proves the words passed through human fingers on a real device — deception is expensive, not impossible.")
                            .font(Theme.subhead)
                            .foregroundStyle(Theme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let webVerifyURL {
                        Link(destination: webVerifyURL) {
                            HStack {
                                Image(systemName: "arrow.up.right.square")
                                Text("Verify independently on the web")
                                    .fontWeight(.semibold)
                            }
                            .font(Theme.subhead)
                            .foregroundStyle(Theme.accent)
                        }
                        .padding(.top, Theme.xs)
                    }
                }
                .padding(Theme.xl)
            }
            .background(Theme.bg)
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

    // MARK: - Status Header

    private var statusHeader: some View {
        HStack(spacing: Theme.md) {
            Image(systemName: statusIcon)
                .font(.system(.largeTitle))
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: Theme.xs) {
                Text(statusTitle)
                    .font(.system(.title3, design: .serif).weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text(statusDetail)
                    .font(Theme.subhead)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var statusIcon: String {
        switch status {
        case .verified: return "checkmark.seal.fill"
        case .verifying: return "checkmark.seal"
        case .failed: return "xmark.seal"
        case .unverified: return "seal"
        }
    }

    private var statusColor: Color {
        switch status {
        case .verified: return Theme.accent
        case .verifying: return Theme.inkTertiary
        case .failed: return Theme.warning
        case .unverified: return Theme.inkTertiary
        }
    }

    private var statusTitle: String {
        switch status {
        case .verified: return "Human verified"
        case .verifying: return "Checking proof…"
        case .failed: return "Proof didn't check out"
        case .unverified: return "No proof yet"
        }
    }

    private var statusDetail: String {
        switch status {
        case .verified:
            return "@\(authorHandle) typed this post by hand on a genuine Apple device. The cryptographic proof checks out."
        case .verifying:
            return "Fetching the proof record from @\(authorHandle)'s data server and re-running the cryptography."
        case .failed(let reason):
            return "Verification failed: \(reason). The proof may be missing, damaged, or the author's server may be unreachable."
        case .unverified:
            return "This post doesn't carry a Speakwrite proof."
        }
    }

    private func checkRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Theme.md) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Theme.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.subhead.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(Theme.subhead)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#if DEBUG
#Preview("Verified") {
    ProofDetailView(
        status: .verified,
        authorHandle: "alice.bsky.social",
        postUri: "at://did:plc:abc/app.bsky.feed.post/3k44diikxo2f"
    )
}

#Preview("Failed") {
    ProofDetailView(
        status: .failed("No proof record"),
        authorHandle: "alice.bsky.social",
        postUri: "at://did:plc:abc/app.bsky.feed.post/3k44diikxo2f"
    )
}
#endif
