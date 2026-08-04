import AVFoundation
import CryptoKit
import SwiftUI
import UIKit

/// Camera-only capture (no gallery picker) — enforces the attested guarantee.
struct CameraCaptureView: UIViewControllerRepresentable {
    let mode: CameraMode
    let onCapture: (CapturedMedia) -> Void
    var onError: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator

        switch mode {
        case .photo:
            picker.mediaTypes = ["public.image"]
        case .video:
            picker.mediaTypes = ["public.movie"]
            picker.videoMaximumDuration = 60
            picker.videoQuality = .typeMedium
        }

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onError: onError, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        enum VideoProcessingError: Error {
            case exportFailed
        }

        let onCapture: (CapturedMedia) -> Void
        let onError: ((String) -> Void)?
        let dismiss: DismissAction

        init(onCapture: @escaping (CapturedMedia) -> Void, onError: ((String) -> Void)?, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.onError = onError
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                // Photo capture — resize + compress to fit Bluesky's 976KB blob limit
                let resized = Self.resizeForUpload(image, maxDimension: 1500)
                guard let jpegData = Self.compressToFit(resized, maxBytes: 950_000) else {
                    onError?("Photo too large to process. Try again.")
                    dismiss()
                    return
                }
                let hash = Data(SHA256.hash(data: jpegData))
                let thumbnail = Self.generateThumbnail(from: resized, size: CGSize(width: 144, height: 144))
                let media = CapturedMedia(
                    data: jpegData,
                    mimeType: "image/jpeg",
                    thumbnail: thumbnail,
                    sha256Hash: hash
                )
                onCapture(media)
            } else if let videoURL = info[.mediaURL] as? URL {
                // Video capture — remuxing, hashing, and thumbnail generation are heavy,
                // so run them off the main thread and deliver the result on the main actor.
                let onCapture = self.onCapture
                let onError = self.onError
                Task.detached(priority: .userInitiated) {
                    do {
                        let media = try await Coordinator.processVideo(at: videoURL)
                        await MainActor.run { onCapture(media) }
                    } catch {
                        await MainActor.run { onError?("Couldn't process video. Try again.") }
                    }
                    // Clean up the picker's temp file once we're done with it.
                    try? FileManager.default.removeItem(at: videoURL)
                }
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }

        // MARK: - Video Processing (background)

        /// Remux the recorded QuickTime movie into a real MP4 container, hash the
        /// exported bytes (the hash must match the uploaded bytes), and build a thumbnail.
        static func processVideo(at sourceURL: URL) async throws -> CapturedMedia {
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")
            defer { try? FileManager.default.removeItem(at: outputURL) }

            try await exportToMP4(asset: AVURLAsset(url: sourceURL), outputURL: outputURL)

            let videoData = try Data(contentsOf: outputURL)
            let hash = Data(SHA256.hash(data: videoData))
            let thumbnail = await generateVideoThumbnail(url: outputURL)

            return CapturedMedia(
                data: videoData,
                mimeType: "video/mp4",
                thumbnail: thumbnail,
                sha256Hash: hash
            )
        }

        /// Export to an MP4 container — passthrough first (container remux, no re-encode),
        /// falling back to a medium-quality re-encode if passthrough fails.
        private static func exportToMP4(asset: AVAsset, outputURL: URL) async throws {
            for preset in [AVAssetExportPresetPassthrough, AVAssetExportPresetMediumQuality] {
                guard let session = AVAssetExportSession(asset: asset, presetName: preset) else { continue }
                session.outputURL = outputURL
                session.outputFileType = .mp4
                session.shouldOptimizeForNetworkUse = true
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    session.exportAsynchronously { continuation.resume() }
                }
                if session.status == .completed { return }
                try? FileManager.default.removeItem(at: outputURL)
            }
            throw VideoProcessingError.exportFailed
        }

        /// Iteratively compress JPEG until it fits under maxBytes.
        static func compressToFit(_ image: UIImage, maxBytes: Int) -> Data? {
            var quality: CGFloat = 0.80
            while quality >= 0.10 {
                if let data = image.jpegData(compressionQuality: quality), data.count <= maxBytes {
                    return data
                }
                quality -= 0.10
            }
            // Last resort — lowest quality
            return image.jpegData(compressionQuality: 0.05)
        }

        /// Downscale image so the longest side is at most `maxDimension` points.
        static func resizeForUpload(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
            let size = image.size
            guard max(size.width, size.height) > maxDimension else { return image }
            let scale = maxDimension / max(size.width, size.height)
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }

        /// Aspect-fill thumbnail: scale the image to cover the target size, center it, and crop.
        static func generateThumbnail(from image: UIImage, size: CGSize) -> UIImage {
            let imageSize = image.size
            guard imageSize.width > 0, imageSize.height > 0 else { return image }
            let scale = max(size.width / imageSize.width, size.height / imageSize.height)
            let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let origin = CGPoint(
                x: (size.width - scaledSize.width) / 2,
                y: (size.height - scaledSize.height) / 2
            )
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: origin, size: scaledSize))
            }
        }

        /// Async thumbnail via AVAssetImageGenerator.image(at:) — replaces the
        /// deprecated synchronous copyCGImage(at:actualTime:).
        private static func generateVideoThumbnail(url: URL) async -> UIImage {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 432, height: 432)
            let time = CMTime(seconds: 0.5, preferredTimescale: 600)
            if let result = try? await generator.image(at: time) {
                return generateThumbnail(from: UIImage(cgImage: result.image), size: CGSize(width: 144, height: 144))
            }
            return UIImage(systemName: "video.fill") ?? UIImage()
        }
    }
}

#if DEBUG
#Preview {
    // CameraCaptureView requires camera hardware — preview shows placeholder
    Text("Camera preview requires device")
        .font(.system(size: 15, design: .monospaced))
        .foregroundStyle(.secondary)
}
#endif
