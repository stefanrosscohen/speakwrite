import AVKit
import SwiftUI

/// Grid layout for displaying 1-4 post images with full-screen tap-to-view.
struct PostImagesView: View {
    let images: [EmbedImageView]
    @State private var selectedImage: EmbedImageView?
    @Environment(\.colorScheme) private var colorScheme

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
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .fullScreenCover(item: $selectedImage) { image in
            FullScreenImageView(image: image)
        }
    }

    private func singleImage(_ image: EmbedImageView) -> some View {
        AsyncImage(url: URL(string: image.thumb)) { phase in
            switch phase {
            case .success(let img):
                img.resizable().scaledToFill()
            case .failure:
                imagePlaceholder
            default:
                imagePlaceholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 300)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { selectedImage = image }
    }

    private func imageCell(_ image: EmbedImageView, aspectRatio: CGFloat) -> some View {
        AsyncImage(url: URL(string: image.thumb)) { phase in
            switch phase {
            case .success(let img):
                img.resizable().scaledToFill()
            case .failure:
                imagePlaceholder
            default:
                imagePlaceholder
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { selectedImage = image }
    }

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(Theme.surface(colorScheme))
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(Theme.textTertiary(colorScheme))
            }
    }
}

// MARK: - Post Video View

/// Thumbnail with play button; taps to full-screen video player.
struct PostVideoView: View {
    let thumbnailURL: String
    let playlistURL: String
    @State private var showPlayer = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            AsyncImage(url: URL(string: thumbnailURL)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                case .failure:
                    Rectangle().fill(Theme.surface(colorScheme))
                default:
                    Rectangle().fill(Theme.surface(colorScheme))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 300)
            .clipped()

            // Play button overlay
            Image(systemName: "play.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(radius: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onTapGesture { showPlayer = true }
        .fullScreenCover(isPresented: $showPlayer) {
            VideoPlayerView(url: URL(string: playlistURL)!)
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

            AsyncImage(url: URL(string: image.fullsize)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failure:
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                        Text("Failed to load image")
                            .font(.system(size: 14))
                    }
                    .foregroundStyle(.white.opacity(0.6))
                default:
                    ProgressView()
                        .tint(.white)
                }
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
            }
        }
    }
}
