import SwiftUI

/// Reusable avatar view with size variants and placeholder fallback.
struct AvatarView: View {
    let url: String?
    let handle: String?
    let size: AvatarSize

    enum AvatarSize {
        case small, medium, large

        var points: CGFloat {
            switch self {
            case .small: return Theme.avatarSmall
            case .medium: return Theme.avatarMedium
            case .large: return Theme.avatarLarge
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 18
            case .large: return 28
            }
        }
    }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let url, let imageURL = URL(string: url) {
            AsyncImage(url: imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                placeholder
            }
            .frame(width: size.points, height: size.points)
            .clipShape(Circle())
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Circle()
            .fill(Theme.surface(colorScheme))
            .frame(width: size.points, height: size.points)
            .overlay {
                Text(String((handle?.first ?? "?")).uppercased())
                    .font(.system(size: size.fontSize, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.accent)
            }
    }
}

#if DEBUG
#Preview("Avatar Sizes") {
    HStack(spacing: 20) {
        AvatarView(url: nil, handle: "alice.bsky.social", size: .small)
        AvatarView(url: nil, handle: "bob.bsky.social", size: .medium)
        AvatarView(url: nil, handle: nil, size: .large)
    }
    .padding()
}
#endif
