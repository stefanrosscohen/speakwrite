import SwiftUI

/// Horizontal strip of media thumbnails for the compose screen.
struct MediaPreviewStrip: View {
    let photos: [CapturedMedia]
    let video: CapturedMedia?
    let onRemovePhoto: (UUID) -> Void
    let onRemoveVideo: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(photos) { photo in
                    mediaThumbnail(image: photo.thumbnail, isVideo: false) {
                        onRemovePhoto(photo.id)
                    }
                }

                if let video {
                    mediaThumbnail(image: video.thumbnail, isVideo: true) {
                        onRemoveVideo()
                    }
                }
            }
            .padding(.horizontal, Theme.lg)
            .padding(.vertical, 8)
        }
    }

    private func mediaThumbnail(image: UIImage, isVideo: Bool, onRemove: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSm))

            // Video badge
            if isVideo {
                Image(systemName: "play.fill")
                    .font(Theme.caption)
                    .foregroundStyle(.white)
                    .padding(4)
                    .background(Circle().fill(.black.opacity(0.6)))
                    .offset(x: -4, y: 4)
            }

            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .background(Circle().fill(.black.opacity(0.5)))
            }
            .offset(x: 4, y: -4)
            .accessibilityLabel(isVideo ? "Remove video" : "Remove photo")
        }
    }
}

#if DEBUG
#Preview {
    // MediaPreviewStrip requires CapturedMedia with UIImage thumbnails — preview shows placeholder
    MediaPreviewStrip(
        photos: [],
        video: nil,
        onRemovePhoto: { _ in },
        onRemoveVideo: {}
    )
    .padding()
}
#endif
