import SwiftUI

/// Bottom toolbar showing character count ring, stats, and publish button.
struct PostBarView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showPublishSheet: Bool

    private let charLimit = 300

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.md) {
                CharacterCountRing(count: graphemeCount, limit: charLimit)

                HStack(spacing: 14) {
                    if let session = viewModel.sessionService {
                        HStack(spacing: Theme.xs) {
                            Image(systemName: "keyboard").font(Theme.monoSmall)
                            Text("\(session.keystrokeCount)").font(Theme.monoCaption)
                        }
                        HStack(spacing: Theme.xs) {
                            Image(systemName: "link").font(Theme.monoSmall)
                            Text("\(session.commitmentCount)").font(Theme.monoCaption)
                        }
                    }
                }
                .foregroundStyle(Theme.textSecondary(colorScheme))

                Spacer()

                Button {
                    showPublishSheet = true
                } label: {
                    Text("Publish")
                        .font(Theme.monoBold)
                        .padding(.horizontal, Theme.xl)
                        .padding(.vertical, Theme.sm)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .foregroundStyle(.black)
                .clipShape(Capsule())
                .disabled(viewModel.postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isOverLimit)
            }
            .padding(.horizontal, Theme.lg)
            .padding(.vertical, 10)
        }
    }

    private var graphemeCount: Int { viewModel.postText.count }
    private var isOverLimit: Bool { graphemeCount > charLimit }
}

// MARK: - Character Count Ring

struct CharacterCountRing: View {
    let count: Int
    let limit: Int
    @Environment(\.colorScheme) private var colorScheme

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
            Circle().stroke(Theme.surface(colorScheme), lineWidth: 2.5)
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
                    .foregroundStyle(remaining < 0 ? Theme.error : Theme.textSecondary(colorScheme))
            }
        }
        .frame(width: 30, height: 30)
        .animation(.easeInOut(duration: 0.15), value: count)
    }
}
