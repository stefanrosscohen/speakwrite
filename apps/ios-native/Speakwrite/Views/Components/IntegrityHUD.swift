import SwiftUI

/// Live "proof ritual" strip shown while composing. Makes the invisible
/// guarantees visible: every keystroke is counted, restrictions are active,
/// and attempted violations (paste, dictation, hardware keys) are surfaced.
struct IntegrityHUD: View {
    let keystrokeCount: Int
    let violationCount: Int
    var wordCount: Int = 0
    var deletionCount: Int = 0
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: Theme.md) {
            // The typing odometer: keystrokes, words, deletions
            odometerItem(icon: "keyboard", value: keystrokeCount, active: keystrokeCount > 0)

            odometerItem(icon: "text.word.spacing", value: wordCount, active: wordCount > 0)

            if deletionCount > 0 {
                odometerItem(icon: "delete.left", value: deletionCount, active: false)
            }

            Rectangle()
                .fill(Theme.separator(colorScheme))
                .frame(width: 1, height: 12)

            // Restriction state
            HStack(spacing: 4) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 11))
                Text("paste · dictation off")
                    .font(Theme.monoSmall)
            }
            .foregroundStyle(Theme.textTertiary(colorScheme))
            .layoutPriority(-1)

            Spacer(minLength: 0)

            // Violations blocked
            if violationCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 11))
                    Text("\(violationCount) blocked")
                        .font(Theme.monoCaption)
                }
                .foregroundStyle(Theme.warning)
            }
        }
        .padding(.horizontal, Theme.lg)
        .padding(.vertical, 6)
        .background(Theme.surface(colorScheme).opacity(0.6))
    }

    private func odometerItem(icon: String, value: Int, active: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text("\(value)")
                .font(Theme.monoCaption)
                .contentTransition(.numericText())
        }
        .foregroundStyle(active ? Theme.accent : Theme.textTertiary(colorScheme))
        .animation(.snappy(duration: 0.15), value: value)
    }
}

#if DEBUG
#Preview("Clean session") {
    IntegrityHUD(keystrokeCount: 132, violationCount: 0, wordCount: 24, deletionCount: 6)
}

#Preview("With violations") {
    IntegrityHUD(keystrokeCount: 12, violationCount: 2, wordCount: 3)
}
#endif
