import CryptoKit
import Foundation
import UIKit

// MARK: - Captured Media

struct CapturedMedia: Identifiable {
    let id = UUID()
    let data: Data
    let mimeType: String       // "image/jpeg" or "video/mp4"
    let thumbnail: UIImage
    let sha256Hash: Data
}

enum CameraMode {
    case photo
    case video
}

/// Top-level app state. Replaces Zustand store from the web app.
@Observable
@MainActor
final class AppViewModel: InputRestrictedDelegate {
    let attestation = DeviceAttestationService()
    let verification = VerificationService()
    let worldID = WorldIDService()
    var atproto: ATProtoService

    // Navigation — default to feed for preview
    var selectedTab: AppTab = .timeline

    // Own profile (loaded after login / session restore)
    var myProfile: ProfileViewDetailed?

    // Compose state
    var postText: String = ""
    var isPublishing: Bool = false
    var publishError: String?
    var lastPublishedURI: String?
    var keystrokeCount: Int = 0
    var violationCount: Int = 0

    // Media capture state
    var capturedPhotos: [CapturedMedia] = []
    var capturedVideo: CapturedMedia? = nil
    var showCamera = false
    var cameraMode: CameraMode = .photo
    var videoProcessingStatus: String? = nil  // Shown during video upload/transcoding

    // Verified feed state
    var verifiedPosts: [VerifiedPost] = []
    var feedCursor: String?
    var isFeedLoading: Bool = false

    // Timeline feed state (For You — discover feed)
    var timelinePosts: [TimelinePost] = []
    var timelineCursor: String?
    var isTimelineLoading: Bool = false

    // Following feed state (authenticated following timeline)
    var followingPosts: [TimelinePost] = []
    var followingCursor: String?
    var isFollowingLoading: Bool = false

    // Diagnostic: last load error per feed (shown in empty state for debugging)
    var lastTimelineError: String?
    var lastFollowingError: String?
    var lastVerifiedError: String?
    var debugLoadingNote: String?

    enum AppTab: Hashable {
        case timeline
        case verified
        case compose
        case settings
    }

    init() {
        self.atproto = ATProtoService()
        FeedCache.migrateIfNeeded()
        // Restore cached feeds instantly
        verifiedPosts = FeedCache.load("verified") ?? []
        followingPosts = FeedCache.load("following") ?? []
        timelinePosts = FeedCache.load("timeline") ?? []
    }

    // MARK: - InputRestrictedDelegate

    nonisolated func textDidChange(_ text: String) {
        Task { @MainActor in
            self.postText = text
        }
    }

    nonisolated func keystrokeCountDidChange(_ count: Int) {
        Task { @MainActor in
            self.keystrokeCount = count
        }
    }

    nonisolated func violationCountDidChange(_ count: Int) {
        Task { @MainActor in
            self.violationCount = count
        }
    }

    // MARK: - Profile

    func loadMyProfile() async {
        guard let did = atproto.did else { return }
        do {
            myProfile = try await atproto.getProfile(actor: did)
        } catch {
            // Silently fail — profile is optional UI
        }
    }

    // MARK: - Compose Flow

    func publish() async {
        let text = postText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasMedia = !capturedPhotos.isEmpty || capturedVideo != nil
        guard !text.isEmpty || hasMedia else {
            publishError = "Post cannot be empty."
            return
        }

        isPublishing = true
        publishError = nil

        do {
            // Initialize attestation (generates + attests App Attest key if needed)
            let keyId = try await attestation.initialize()

            // Collect media hashes (hex) for the proof record
            var mediaHashesHex: [String] = []
            if let video = capturedVideo {
                mediaHashesHex.append(video.sha256Hash.map { String(format: "%02x", $0) }.joined())
            } else {
                for photo in capturedPhotos {
                    mediaHashesHex.append(photo.sha256Hash.map { String(format: "%02x", $0) }.joined())
                }
            }

            // Compute content hash
            // Text-only: SHA256(text) — backward compatible
            // With media: SHA256(SHA256(text) + sorted_media_sha256_hashes)
            let textHashData = Data(SHA256.hash(data: Data(text.utf8)))
            let contentHashData: Data
            if mediaHashesHex.isEmpty {
                contentHashData = textHashData
            } else {
                var compositeInput = textHashData
                for hashHex in mediaHashesHex.sorted() {
                    if let hashData = Data(hexString: hashHex) {
                        compositeInput.append(hashData)
                    }
                }
                contentHashData = Data(SHA256.hash(data: compositeInput))
            }
            let contentHashHex = contentHashData.map { String(format: "%02x", $0) }.joined()

            // Generate App Attest assertion over the content hash
            let assertionData = try await attestation.generateAssertion(contentHash: contentHashData)

            // Get attestation object (Apple's cert chain)
            guard let attestationObject = await attestation.attestationObjectBase64 else {
                throw AttestationError.notAttested
            }

            // Build attestation record
            let record = AttestationRecord(
                keyId: keyId,
                attestationObject: attestationObject,
                assertion: assertionData.base64EncodedString(),
                contentHash: contentHashHex,
                appId: Bundle.main.bundleIdentifier ?? "io.speakwrite.app",
                mediaHashes: mediaHashesHex.isEmpty ? nil : mediaHashesHex
            )

            // Upload media blobs
            var embed: [String: Any]? = nil
            var uploadedImageURLs: [EmbedImageView] = []

            if let video = capturedVideo {
                guard let did = atproto.did else { throw ATProtoError.notLoggedIn }

                // Step 1: Upload video to video.bsky.app
                videoProcessingStatus = "Uploading video..."
                let jobStatus = try await atproto.uploadVideo(
                    videoData: video.data, did: did, filename: "speakwrite_\(Int(Date().timeIntervalSince1970)).mp4"
                )

                // Step 2: Poll until Bluesky finishes transcoding
                let blob: [String: Any]
                if let immediateBlob = jobStatus.blob {
                    blob = immediateBlob
                } else {
                    videoProcessingStatus = "Processing video..."
                    blob = try await atproto.pollVideoJob(jobId: jobStatus.jobId) { [weak self] state in
                        Task { @MainActor in
                            switch state {
                            case "JOB_STATE_COMPLETED": self?.videoProcessingStatus = "Video ready!"
                            default: self?.videoProcessingStatus = "Processing video…"
                            }
                        }
                    }
                }
                videoProcessingStatus = nil

                embed = [
                    "$type": "app.bsky.embed.video",
                    "video": blob,
                ]
            } else if !capturedPhotos.isEmpty {
                var imageEntries: [[String: Any]] = []
                for photo in capturedPhotos {
                    let blob = try await atproto.uploadBlob(imageData: photo.data, mimeType: photo.mimeType)
                    imageEntries.append(["alt": "", "image": blob])

                    // Build optimistic image view from blob ref
                    if let ref = blob["ref"] as? [String: Any],
                       let link = ref["$link"] as? String,
                       let did = atproto.did {
                        let thumbURL = "https://cdn.bsky.app/img/feed_thumbnail/plain/\(did)/\(link)@jpeg"
                        let fullURL = "https://cdn.bsky.app/img/feed_fullsize/plain/\(did)/\(link)@jpeg"
                        uploadedImageURLs.append(EmbedImageView(thumb: thumbURL, fullsize: fullURL, alt: ""))
                    }
                }
                embed = [
                    "$type": "app.bsky.embed.images",
                    "images": imageEntries,
                ]
            }

            // Publish to AT Protocol
            let result = try await atproto.publishAttestedPost(
                text: text, attestation: record, embed: embed
            )
            lastPublishedURI = result.uri

            // Optimistic insert — show the post in verified feed immediately
            let optimisticPost = VerifiedPost(
                uri: result.uri,
                cid: result.cid,
                author: PostAuthor(
                    did: atproto.did ?? "",
                    handle: atproto.handle ?? "",
                    displayName: myProfile?.displayName,
                    avatar: myProfile?.avatar,
                    viewer: nil
                ),
                text: text,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                likeCount: 0, repostCount: 0, replyCount: 0,
                viewer: nil,
                images: uploadedImageURLs.isEmpty ? nil : uploadedImageURLs,
                videoURL: nil, videoThumbnail: nil
            )
            verifiedPosts.insert(optimisticPost, at: 0)

            // Reset for next post
            postText = ""
            keystrokeCount = 0
            violationCount = 0
            capturedPhotos = []
            capturedVideo = nil
            videoProcessingStatus = nil
            isPublishing = false

            // Navigate to verified feed where the new post appears
            selectedTab = .verified
            lastPublishedURI = nil
            return
        } catch {
            publishError = error.localizedDescription
            videoProcessingStatus = nil
        }

        isPublishing = false
    }

    // MARK: - Reply Flow (Attested)

    func publishReply(
        text: String,
        parentUri: String,
        parentCid: String,
        capturedPhotos: [CapturedMedia] = [],
        capturedVideo: CapturedMedia? = nil,
        onVideoStatus: ((String?) -> Void)? = nil
    ) async throws {
        // 1. Initialize attestation (generates + attests App Attest key if needed)
        let keyId = try await attestation.initialize()

        // 2. Collect media hashes (hex) for the proof record
        var mediaHashesHex: [String] = []
        if let video = capturedVideo {
            mediaHashesHex.append(video.sha256Hash.map { String(format: "%02x", $0) }.joined())
        } else {
            for photo in capturedPhotos {
                mediaHashesHex.append(photo.sha256Hash.map { String(format: "%02x", $0) }.joined())
            }
        }

        // 3. Compute content hash
        // Text-only: SHA256(text) — backward compatible
        // With media: SHA256(SHA256(text) + sorted_media_sha256_hashes)
        let textHashData = Data(SHA256.hash(data: Data(text.utf8)))
        let contentHashData: Data
        if mediaHashesHex.isEmpty {
            contentHashData = textHashData
        } else {
            var compositeInput = textHashData
            for hashHex in mediaHashesHex.sorted() {
                if let hashData = Data(hexString: hashHex) {
                    compositeInput.append(hashData)
                }
            }
            contentHashData = Data(SHA256.hash(data: compositeInput))
        }
        let contentHashHex = contentHashData.map { String(format: "%02x", $0) }.joined()

        // 4. Generate App Attest assertion over the content hash
        let assertionData = try await attestation.generateAssertion(contentHash: contentHashData)

        // 5. Get attestation object (Apple's cert chain)
        guard let attestationObject = await attestation.attestationObjectBase64 else {
            throw AttestationError.notAttested
        }

        // 6. Build attestation record
        let record = AttestationRecord(
            keyId: keyId,
            attestationObject: attestationObject,
            assertion: assertionData.base64EncodedString(),
            contentHash: contentHashHex,
            appId: Bundle.main.bundleIdentifier ?? "io.speakwrite.app",
            mediaHashes: mediaHashesHex.isEmpty ? nil : mediaHashesHex
        )

        // 7. Upload media blobs
        var embed: [String: Any]? = nil

        if let video = capturedVideo {
            guard let did = atproto.did else { throw ATProtoError.notLoggedIn }

            onVideoStatus?("Uploading video...")
            let jobStatus = try await atproto.uploadVideo(
                videoData: video.data, did: did, filename: "speakwrite_\(Int(Date().timeIntervalSince1970)).mp4"
            )

            let blob: [String: Any]
            if let immediateBlob = jobStatus.blob {
                blob = immediateBlob
            } else {
                onVideoStatus?("Processing video...")
                blob = try await atproto.pollVideoJob(jobId: jobStatus.jobId) { state in
                    Task { @MainActor in
                        switch state {
                        case "JOB_STATE_COMPLETED": onVideoStatus?("Video ready!")
                        default: onVideoStatus?("Processing video…")
                        }
                    }
                }
            }
            onVideoStatus?(nil)

            embed = [
                "$type": "app.bsky.embed.video",
                "video": blob,
            ]
        } else if !capturedPhotos.isEmpty {
            var imageEntries: [[String: Any]] = []
            for photo in capturedPhotos {
                let blob = try await atproto.uploadBlob(imageData: photo.data, mimeType: photo.mimeType)
                imageEntries.append(["alt": "", "image": blob])
            }
            embed = [
                "$type": "app.bsky.embed.images",
                "images": imageEntries,
            ]
        }

        // 8. Publish with reply field + embed
        let _ = try await atproto.publishAttestedPost(
            text: text,
            attestation: record,
            embed: embed,
            reply: (parentUri: parentUri, parentCid: parentCid)
        )
    }

    // MARK: - Quote Post Flow (Attested)

    func publishQuotePost(text: String, quotedUri: String, quotedCid: String) async throws {
        let keyId = try await attestation.initialize()

        let textHashData = Data(SHA256.hash(data: Data(text.utf8)))
        let contentHashHex = textHashData.map { String(format: "%02x", $0) }.joined()

        let assertionData = try await attestation.generateAssertion(contentHash: textHashData)

        guard let attestationObject = await attestation.attestationObjectBase64 else {
            throw AttestationError.notAttested
        }

        let record = AttestationRecord(
            keyId: keyId,
            attestationObject: attestationObject,
            assertion: assertionData.base64EncodedString(),
            contentHash: contentHashHex,
            appId: Bundle.main.bundleIdentifier ?? "io.speakwrite.app",
            mediaHashes: nil
        )

        let embed: [String: Any] = [
            "$type": "app.bsky.embed.record",
            "record": [
                "uri": quotedUri,
                "cid": quotedCid,
            ] as [String: Any],
        ]

        let _ = try await atproto.publishAttestedPost(
            text: text,
            attestation: record,
            embed: embed
        )
    }

    // MARK: - Preload All Feeds

    func loadAllFeeds() async {
        async let feed: () = loadFeed()
        async let following: () = loadFollowing()
        async let timeline: () = loadTimeline()
        _ = await (feed, following, timeline)
    }

    // MARK: - Verified Feed

    func loadFeed() async {
        // Only show loading spinner on first load (no cached posts)
        let isFirstLoad = verifiedPosts.isEmpty
        if isFirstLoad { isFeedLoading = true }

        do {
            let result = try await atproto.fetchVerifiedFeed(cursor: nil)
            if !result.posts.isEmpty || verifiedPosts.isEmpty {
                let fetchedURIs = Set(result.posts.map(\.uri))
                let optimistic = verifiedPosts.filter { !fetchedURIs.contains($0.uri) }
                verifiedPosts = optimistic + result.posts
                feedCursor = result.cursor
                FeedCache.save(verifiedPosts, key: "verified")
            }
            lastVerifiedError = nil
        } catch {
            lastVerifiedError = String(describing: error)
            print("[Feed] Error loading verified feed: \(error)")
        }

        if isFirstLoad { isFeedLoading = false }
    }

    func loadMoreFeed() async {
        guard let cursor = feedCursor else { return }

        do {
            let result = try await atproto.fetchVerifiedFeed(cursor: cursor)
            verifiedPosts.append(contentsOf: result.posts)
            feedCursor = result.cursor
        } catch {
            print("[Feed] Error loading more: \(error)")
        }
    }

    // MARK: - Timeline (For You / Discover Feed)

    func loadTimeline() async {
        isTimelineLoading = true
        debugLoadingNote = "timeline: pds=\(atproto.pdsURLDebug ?? "nil") tok=\(atproto.hasAccessTokenDebug)"

        do {
            let result = try await withTimeout(seconds: 12) {
                try await self.atproto.fetchTimeline(cursor: nil)
            }
            timelinePosts = result.posts
            timelineCursor = result.cursor
            FeedCache.save(timelinePosts, key: "timeline")
            lastTimelineError = nil
        } catch {
            lastTimelineError = String(describing: error)
            print("[Timeline] Error loading discover feed: \(error)")
        }

        isTimelineLoading = false
    }

    func loadMoreTimeline() async {
        guard let cursor = timelineCursor else { return }

        do {
            let result = try await atproto.fetchTimeline(cursor: cursor)
            timelinePosts.append(contentsOf: result.posts)
            timelineCursor = result.cursor
        } catch {
            print("[Timeline] Error loading more: \(error)")
        }
    }

    // MARK: - Following Timeline (Authenticated)

    func loadFollowing() async {
        isFollowingLoading = true
        debugLoadingNote = "following: pds=\(atproto.pdsURLDebug ?? "nil") tok=\(atproto.hasAccessTokenDebug) did=\(atproto.did ?? "nil")"

        do {
            let result = try await withTimeout(seconds: 12) {
                try await self.atproto.fetchFollowingTimeline(cursor: nil)
            }
            followingPosts = result.posts
            followingCursor = result.cursor
            FeedCache.save(followingPosts, key: "following")
            lastFollowingError = nil
        } catch {
            lastFollowingError = String(describing: error)
            print("[Timeline] Error loading following feed: \(error)")
        }

        isFollowingLoading = false
    }

    func loadMoreFollowing() async {
        guard let cursor = followingCursor else { return }

        do {
            let result = try await atproto.fetchFollowingTimeline(cursor: cursor)
            followingPosts.append(contentsOf: result.posts)
            followingCursor = result.cursor
        } catch {
            print("[Following] Error loading more: \(error)")
        }
    }

}

// MARK: - Feed Cache

enum FeedCache {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    /// Bump this when the cache format changes to invalidate old caches.
    private static let cacheVersion = 3
    private static let versionKey = "feedCacheVersion"

    private static func url(for key: String) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("feed-\(key).json")
    }

    /// Clear all feed caches if the version has changed.
    static func migrateIfNeeded() {
        let current = UserDefaults.standard.integer(forKey: versionKey)
        if current < cacheVersion {
            for key in ["verified", "following", "timeline"] {
                try? FileManager.default.removeItem(at: url(for: key))
            }
            UserDefaults.standard.set(cacheVersion, forKey: versionKey)
        }
    }

    static func save<T: Encodable>(_ items: [T], key: String) {
        do {
            let data = try encoder.encode(items)
            try data.write(to: url(for: key), options: .atomic)
        } catch {
            print("[FeedCache] Save failed for \(key): \(error)")
        }
    }

    static func load<T: Decodable>(_ key: String) -> [T]? {
        let file = url(for: key)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        do {
            let data = try Data(contentsOf: file)
            return try decoder.decode([T].self, from: data)
        } catch {
            print("[FeedCache] Load failed for \(key): \(error)")
            try? FileManager.default.removeItem(at: file)
            return nil
        }
    }

}

// MARK: - Timeout Helper

/// Runs `operation` with a deadline; throws `URLError(.timedOut)` if it doesn't finish in time.
func withTimeout<T: Sendable>(seconds: Double, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw URLError(.timedOut)
        }
        defer { group.cancelAll() }
        return try await group.next()!
    }
}
