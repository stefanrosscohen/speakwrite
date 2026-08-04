import SwiftUI

/// Bottom toolbar showing character count ring and publish button.
struct PostBarView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var showPublishConfirm = false

    private let charLimit = 300

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.md) {
                CharacterCountRing(count: graphemeCount, limit: charLimit)

                if viewModel.keystrokeCount > 0 {
                    HStack(spacing: Theme.xs) {
                        Image(systemName: "keyboard")
                            .font(Theme.caption)
                        Text("\(viewModel.keystrokeCount)")
                            .font(Theme.monoCaption)
                    }
                    .foregroundStyle(Theme.textTertiary)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(viewModel.keystrokeCount) keystrokes recorded")
                }

                Spacer()

                if viewModel.isPublishing {
                    HStack(spacing: Theme.sm) {
                        ProgressView()
                            .tint(Theme.accent)
                        if let status = viewModel.videoProcessingStatus {
                            Text(status)
                                .font(Theme.monoSmall)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(.trailing, Theme.sm)
                } else if viewModel.lastPublishedURI != nil {
                    HStack(spacing: Theme.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.accent)
                        Text("Published")
                            .font(Theme.monoBold)
                            .foregroundStyle(Theme.accent)
                    }
                } else {
                    Button {
                        showPublishConfirm = true
                    } label: {
                        Text("Publish")
                            .font(Theme.monoBold)
                            .padding(.horizontal, Theme.xl)
                            .padding(.vertical, Theme.sm)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .foregroundStyle(Theme.onAccent)
                    .clipShape(Capsule())
                    .disabled(
                        (viewModel.postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                         && viewModel.capturedPhotos.isEmpty
                         && viewModel.capturedVideo == nil)
                        || isOverLimit
                    )
                }
            }
            .padding(.horizontal, Theme.lg)
            .padding(.vertical, 10)

            if let error = viewModel.publishError {
                HStack {
                    Text(error)
                        .font(Theme.monoSmall)
                        .foregroundStyle(Theme.error)
                    Spacer()
                    Button("Retry") {
                        viewModel.publishError = nil
                        Task { await viewModel.publish() }
                    }
                    .font(Theme.monoSmall)
                    .foregroundStyle(Theme.accent)
                }
                .padding(.horizontal, Theme.lg)
                .padding(.bottom, Theme.sm)
            }
        }
        .alert("Publish verified post?", isPresented: $showPublishConfirm) {
            Button("Publish", role: .none) {
                viewModel.publishError = nil
                Task { await viewModel.publish() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This post will be cryptographically signed and published to your AT Protocol feed with a Speakwrite proof.")
        }
    }

    private var graphemeCount: Int { viewModel.postText.count }
    private var isOverLimit: Bool { graphemeCount > charLimit }
}

// MARK: - Character Count Ring

struct CharacterCountRing: View {
    let count: Int
    let limit: Int

    private var progress: Double { min(Double(count) / Double(limit), 1.0) }
    private var remaining: Int { limit - count }
    private var ringColor: Color {
        if remaining < 0 { return Theme.error }
        else if remaining <= 20 { return .yellow }
        else { return Theme.accent }
    }
    private var showNumber: Bool { remaining <= 20 }

    var body: some View {
        ZStack {
            Circle().stroke(Theme.surface, lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if count > limit {
                Circle()
                    .trim(from: 0, to: min(Double(count - limit) / Double(limit), 1.0))
                    .stroke(Theme.error, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            if showNumber {
                Text("\(remaining)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(remaining < 0 ? Theme.error : Theme.textSecondary)
            }
        }
        .frame(width: 30, height: 30)
        .animation(.easeInOut(duration: 0.15), value: count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(remaining >= 0
            ? "\(remaining) characters remaining"
            : "\(-remaining) characters over the limit")
    }
}

#if DEBUG
#Preview("Empty") {
    PostBarView()
        .environment(AppViewModel.preview)
}

#Preview("With Text") {
    let vm = AppViewModel.preview
    vm.postText = "Hello, this is a test post with some content!"
    return PostBarView()
        .environment(vm)
}

#Preview("Character Ring") {
    VStack(spacing: 20) {
        CharacterCountRing(count: 0, limit: 300)
        CharacterCountRing(count: 150, limit: 300)
        CharacterCountRing(count: 285, limit: 300)
        CharacterCountRing(count: 310, limit: 300)
    }
    .padding()
}
#endif
