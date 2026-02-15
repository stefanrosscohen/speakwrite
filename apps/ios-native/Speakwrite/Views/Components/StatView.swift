import SwiftUI

/// Reusable stat count display used on profile screens.
struct StatView: View {
    let count: Int
    let label: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(Theme.monoStat)
                .foregroundStyle(Theme.accent)
            Text(label)
                .font(Theme.monoSmall)
                .foregroundStyle(Theme.textSecondary(colorScheme))
        }
    }
}
