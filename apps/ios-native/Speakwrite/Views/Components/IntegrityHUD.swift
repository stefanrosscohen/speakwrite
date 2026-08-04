import SwiftUI

/// Live "proof ritual" strip shown while composing. Makes the invisible
/// guarantees visible: every keystroke is counted, restrictions are active,
/// and attempted violations (paste, dictation, hardware keys) are surfaced.
struct IntegrityHUD: View {
    let keystrokeCount: Int
    let violationCount: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: Theme.md) {
            // Keystrokes typed this session
            HStack(spacing: 4) {
                Image(systemName: "keyboard")
                    .font(.system(size: 11))
                Text("\(keystrokeCount)")
                    .font(Theme.monoCaption)
                    .contentTransition(.numericText())
            }
            .foregroundStyle(keystrokeCount > 0 ? Theme.accent : Theme.textTertiary(colorScheme))
            .animation(.snappy(duration: 0.15), value: keystrokeCount)

            Rectangle()
                .fill(Theme.separator(colorScheme))
                .frame(width: 1, height: 12)

            // Restriction state
            HStack(spacing: 4) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 11))
                Text("paste · dictation · autocorrect off")
                    .font(Theme.monoSmall)
            }
            .foregroundStyle(Theme.textTertiary(colorScheme))

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
}

#if DEBUG
#Preview("Clean session") {
    IntegrityHUD(keystrokeCount: 132, violationCount: 0)
}

#Preview("With violations") {
    IntegrityHUD(keystrokeCount: 12, violationCount: 2)
}
#endif
