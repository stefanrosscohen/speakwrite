import SwiftUI

/// The publish ceremony: a full-screen overlay that walks through the proof
/// pipeline as it actually happens — hash, Secure Enclave signature, publish —
/// and ends on a sealed state with the writing streak. Publishing a verified
/// post is the core ritual of the app; it deserves more than a spinner.
struct PublishCeremonyView: View {
    let stage: AppViewModel.PublishStage
    let hasMedia: Bool
    let streak: Int
    let videoStatus: String?
    var onViewPost: () -> Void
    var onKeepWriting: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private enum StepState {
        case pending, active, done
    }

    private struct CeremonyStep {
        let icon: String
        let label: String
        let state: StepState
    }

    private var isSealed: Bool {
        if case .sealed = stage { return true }
        return false
    }

    private var steps: [CeremonyStep] {
        func state(for position: Int) -> StepState {
            let currentPosition: Int
            switch stage {
            case .hashing: currentPosition = 0
            case .signing: currentPosition = 1
            case .uploadingMedia: currentPosition = 2
            case .publishing: currentPosition = hasMedia ? 3 : 2
            case .sealed: currentPosition = .max
            }
            if position < currentPosition { return .done }
            if position == currentPosition { return .active }
            return .pending
        }

        var result: [CeremonyStep] = [
            CeremonyStep(icon: "number", label: "Hashing your words", state: state(for: 0)),
            CeremonyStep(icon: "cpu", label: "Signing in the Secure Enclave", state: state(for: 1)),
        ]
        if hasMedia {
            result.append(CeremonyStep(
                icon: "photo", label: videoStatus ?? "Uploading media", state: state(for: 2)
            ))
        }
        result.append(CeremonyStep(
            icon: "paperplane", label: "Publishing post + proof", state: state(for: hasMedia ? 3 : 2)
        ))
        return result
    }

    var body: some View {
        ZStack {
            Theme.background(colorScheme)
                .opacity(0.97)
                .ignoresSafeArea()

            if isSealed {
                sealedContent
            } else {
                inProgressContent
            }
        }
        .transition(.opacity)
    }

    // MARK: - In Progress

    private var inProgressContent: some View {
        VStack(spacing: Theme.xxl) {
            Image(systemName: "seal")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.accent)
                .symbolEffect(.pulse, options: .repeating)

            VStack(alignment: .leading, spacing: Theme.lg) {
                ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                    HStack(spacing: Theme.md) {
                        Group {
                            switch step.state {
                            case .done:
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.accent)
                            case .active:
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(Theme.accent)
                            case .pending:
                                Image(systemName: step.icon)
                                    .foregroundStyle(Theme.textTertiary(colorScheme))
                            }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 22)

                        Text(step.label)
                            .font(Theme.mono)
                            .foregroundStyle(
                                step.state == .pending
                                    ? Theme.textTertiary(colorScheme)
                                    : Theme.textPrimary(colorScheme)
                            )
                    }
                }
            }
        }
        .padding(Theme.xxxl)
    }

    // MARK: - Sealed

    private var sealedContent: some View {
        VStack(spacing: Theme.xl) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.accent)
                .symbolEffect(.bounce, value: isSealed)

            Text("Sealed")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.textPrimary(colorScheme))

            Text("Typed by hand, signed by your device,\nproof stored in your repository.")
                .font(Theme.mono)
                .foregroundStyle(Theme.textSecondary(colorScheme))
                .multilineTextAlignment(.center)

            if streak > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "pencil.line")
                    Text(streak == 1 ? "Day 1 of writing by hand" : "\(streak) days of writing by hand")
                }
                .font(Theme.monoBold)
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, Theme.lg)
                .padding(.vertical, Theme.sm)
                .background(Capsule().fill(Theme.accentSubtle))
            }

            Spacer()

            VStack(spacing: Theme.md) {
                Button(action: onViewPost) {
                    Text("See it in the Verified feed")
                        .font(Theme.monoBold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.md)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .foregroundStyle(.black)

                Button(action: onKeepWriting) {
                    Text("Keep writing")
                        .font(Theme.monoBold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.md)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
            }
            .padding(.horizontal, Theme.xxxl)
            .padding(.bottom, Theme.xxxl)
        }
    }
}

#if DEBUG
#Preview("Signing") {
    PublishCeremonyView(
        stage: .signing, hasMedia: false, streak: 3, videoStatus: nil,
        onViewPost: {}, onKeepWriting: {}
    )
}

#Preview("Sealed") {
    PublishCeremonyView(
        stage: .sealed(uri: "at://did:plc:abc/app.bsky.feed.post/3abc"),
        hasMedia: true, streak: 7, videoStatus: nil,
        onViewPost: {}, onKeepWriting: {}
    )
}
#endif
