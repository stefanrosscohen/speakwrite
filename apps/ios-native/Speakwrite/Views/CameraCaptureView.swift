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
                let thumbnail = generateThumbnail(from: resized, size: CGSize(width: 144, height: 144))
                let media = CapturedMedia(
                    data: jpegData,
                    mimeType: "image/jpeg",
                    thumbnail: thumbnail,
                    sha256Hash: hash
                )
                onCapture(media)
            } else if let videoURL = info[.mediaURL] as? URL {
                // Video capture
                guard let videoData = try? Data(contentsOf: videoURL) else {
                    onError?("Couldn't read video file. Try again.")
                    dismiss()
                    return
                }
                let hash = Data(SHA256.hash(data: videoData))
                let thumbnail = generateVideoThumbnail(url: videoURL)
                let media = CapturedMedia(
                    data: videoData,
                    mimeType: "video/mp4",
                    thumbnail: thumbnail,
                    sha256Hash: hash
                )
                onCapture(media)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
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

        private func generateThumbnail(from image: UIImage, size: CGSize) -> UIImage {
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        }

        private func generateVideoThumbnail(url: URL) -> UIImage {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let time = CMTime(seconds: 0.5, preferredTimescale: 600)
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                return UIImage(cgImage: cgImage)
            }
            return UIImage(systemName: "video.fill") ?? UIImage()
        }
    }
}

#if DEBUG
#Preview {
    // CameraCaptureView requires camera hardware — preview shows placeholder
    Text("Camera preview requires device")
        .font(Theme.monoBody)
        .foregroundStyle(.secondary)
}
#endif
