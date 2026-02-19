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

#if DEBUG
#Preview {
    HStack(spacing: 24) {
        StatView(count: 89, label: "Posts")
        StatView(count: 1234, label: "Followers")
        StatView(count: 567, label: "Following")
    }
    .padding()
}
#endif
