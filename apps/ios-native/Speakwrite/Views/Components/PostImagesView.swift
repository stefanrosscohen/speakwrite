import AVKit
import SwiftUI

// MARK: - URLSession Image Loader

/// Manual image loader using URLSession for reliable loading in LazyVStack.
private struct RemoteImage: View {
    let url: URL?
    @State private var uiImage: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if failed {
                Rectangle()
                    .fill(Theme.surface)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundStyle(Theme.textTertiary)
                    }
            } else {
                Rectangle()
                    .fill(Theme.surface)
                    .overlay { ProgressView().tint(Theme.textTertiary) }
            }
        }
        .task(id: url) {
            guard let url, uiImage == nil else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let img = UIImage(data: data) {
                    uiImage = img
                } else {
                    failed = true
                }
            } catch {
                failed = true
            }
        }
    }
}

/// Grid layout for displaying 1-4 post images with optional full-screen tap-to-view.
/// Set `interactive` to false when embedded inside a NavigationLink (e.g. feed rows)
/// so taps navigate to the post detail instead of opening the image fullscreen.
struct PostImagesView: View {
    let images: [EmbedImageView]
    var interactive: Bool = true
    @State private var selectedImage: EmbedImageView?

    var body: some View {
        Group {
            switch images.count {
            case 1:
                singleImage(images[0])
            case 2:
                HStack(spacing: 2) {
                    imageCell(images[0], aspectRatio: 1)
                    imageCell(images[1], aspectRatio: 1)
                }
                .frame(maxHeight: 200)
            case 3:
                HStack(spacing: 2) {
                    imageCell(images[0], aspectRatio: 0.75)
                    VStack(spacing: 2) {
                        imageCell(images[1], aspectRatio: 1)
                        imageCell(images[2], aspectRatio: 1)
                    }
                }
                .frame(maxHeight: 200)
            default: // 4+
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        imageCell(images[0], aspectRatio: 1)
                        imageCell(images[1], aspectRatio: 1)
                    }
                    HStack(spacing: 2) {
                        imageCell(images[2], aspectRatio: 1)
                        if images.count > 3 {
                            imageCell(images[3], aspectRatio: 1)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
        .fullScreenCover(item: $selectedImage) { image in
            FullScreenImageView(image: image)
        }
    }

    private func singleImage(_ image: EmbedImageView) -> some View {
        RemoteImage(url: URL(string: image.thumb))
            .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 300)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture { if interactive { selectedImage = image } }
    }

    private func imageCell(_ image: EmbedImageView, aspectRatio: CGFloat) -> some View {
        RemoteImage(url: URL(string: image.thumb))
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture { if interactive { selectedImage = image } }
    }
}

// MARK: - Post Video View

/// Thumbnail with play button; taps to full-screen video player.
struct PostVideoView: View {
    let thumbnailURL: String
    let playlistURL: String
    @State private var showPlayer = false

    var body: some View {
        ZStack {
            RemoteImage(url: URL(string: thumbnailURL))
                .frame(maxWidth: .infinity, maxHeight: 300)
                .clipped()

            // Play button overlay
            Image(systemName: "play.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(radius: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
        .contentShape(Rectangle())
        .onTapGesture { showPlayer = true }
        .fullScreenCover(isPresented: $showPlayer) {
            if let url = URL(string: playlistURL) {
                VideoPlayerView(url: url)
            }
        }
    }
}

private struct VideoPlayerView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }

            Button {
                player?.pause()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
            }
            .accessibilityLabel("Close")
        }
        .onAppear {
            let p = AVPlayer(url: url)
            player = p
            p.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

// MARK: - Full Screen Image Viewer

private struct FullScreenImageView: View {
    let image: EmbedImageView
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            RemoteImage(url: URL(string: image.fullsize))
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
            }
            .accessibilityLabel("Close")
        }
    }
}

#if DEBUG
#Preview("Single Image") {
    PostImagesView(images: [
        EmbedImageView(thumb: "https://picsum.photos/400/300", fullsize: "https://picsum.photos/800/600", alt: "Sample image"),
    ])
    .padding()
}

#Preview("Two Images") {
    PostImagesView(images: [
        EmbedImageView(thumb: "https://picsum.photos/400/300", fullsize: "https://picsum.photos/800/600", alt: "Image 1"),
        EmbedImageView(thumb: "https://picsum.photos/401/300", fullsize: "https://picsum.photos/801/600", alt: "Image 2"),
    ])
    .padding()
}
#endif
