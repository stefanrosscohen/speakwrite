import SwiftUI

/// Slim, dismissable banner shown above a feed when content may be stale —
/// e.g. the user's PDS is unreachable or the network dropped. Speakwrite's
/// old behavior was to fail silently and show cached posts, which made a
/// dead server look like a broken app.
struct StatusBanner: View {
    let message: String
    var onRetry: (() -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: Theme.sm) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.warning)

            Text(message)
                .font(Theme.monoCaption)
                .foregroundStyle(Theme.textPrimary(colorScheme))
                .lineLimit(2)

            Spacer(minLength: Theme.sm)

            if let onRetry {
                Button("Retry") { onRetry() }
                    .font(Theme.monoBold)
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, Theme.lg)
        .padding(.vertical, Theme.sm)
        .background(Theme.warning.opacity(0.12))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        StatusBanner(message: "Can't reach your server (pds.stefans.house)", onRetry: {})
        StatusBanner(message: "No internet connection")
    }
}
#endif
