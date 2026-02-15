import SwiftUI

/// Shared top-left avatar button used in all tab headers.
struct AvatarButton: View {
    let avatarURL: String?
    let handle: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AvatarView(
                url: avatarURL,
                handle: handle,
                size: .small
            )
        }
    }
}
