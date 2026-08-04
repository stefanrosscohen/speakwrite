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
    var atproto: ATProtoService

    // Navigation — the app opens into the editor: writing is the product,
    // the feeds are a swipe away.
    var selectedTab: AppTab = .compose

    // Own profile (loaded after login / session restore)
    var myProfile: ProfileViewDetailed?

    // Compose state — the draft survives app kills; typing 300 characters by
    // hand is an investment.
    var postText: String = "" {
        didSet {
            guard postText != oldValue else { return }
            UserDefaults.standard.set(postText, forKey: Self.draftKey)
        }
    }
    var isPublishing: Bool = false
    var publishError: String?
    var lastPublishedURI: String?
    var keystrokeCount: Int = 0
    var violationCount: Int = 0
    var deletionCount: Int = 0

    /// The publish ceremony — each stage the proof pipeline moves through,
    /// rendered as a full-screen ritual instead of an anonymous spinner.
    enum PublishStage: Equatable {
        case hashing
        case signing
        case uploadingMedia
        case publishing
        case sealed(uri: String)
    }
    var publishStage: PublishStage?

    /// Stats of the most recently sealed entry — the share card is built
    /// from these after the compose counters reset.
    struct SealedEntry: Equatable {
        let uri: String
        let keystrokes: Int
        let words: Int
        let date: Date
    }
    var lastEntry: SealedEntry?

    /// Consecutive days with at least one verified post.
    var writingStreak: Int = WritingStreak.current()

    private static let draftKey = "sw_draft"

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
    var verifiedFeedError: String?

    // Timeline feed state (For You — discover feed)
    var timelinePosts: [TimelinePost] = []
    var timelineCursor: String?
    var isTimelineLoading: Bool = false
    var timelineFeedError: String?

    // Following feed state (authenticated following timeline)
    var followingPosts: [TimelinePost] = []
    var followingCursor: String?
    var isFollowingLoading: Bool = false
    var followingFeedError: String?

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
        // Restore the in-progress draft
        postText = UserDefaults.standard.string(forKey: Self.draftKey) ?? ""
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

    nonisolated func deletionCountDidChange(_ count: Int) {
        Task { @MainActor in
            self.deletionCount = count
        }
    }

    // MARK: - Sign Out

    /// Sign out and clear all account-scoped state, including the on-disk feed
    /// cache — otherwise the next account sees the previous account's feeds.
    func signOut() {
        atproto.logout()
        myProfile = nil
        verifiedPosts = []
        timelinePosts = []
        followingPosts = []
        feedCursor = nil
        timelineCursor = nil
        followingCursor = nil
        verifiedFeedError = nil
        timelineFeedError = nil
        followingFeedError = nil
        postText = ""
        capturedPhotos = []
        capturedVideo = nil
        lastPublishedURI = nil
        publishStage = nil
        keystrokeCount = 0
        violationCount = 0
        deletionCount = 0
        UserDefaults.standard.removeObject(forKey: Self.draftKey)
        FeedCache.clearAll()
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
            // Stage 1: hash the content
            publishStage = .hashing

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

            // Stage 2: sign in the Secure Enclave.
            // Initialize attestation (generates + attests App Attest key if needed)
            publishStage = .signing
            let keyId = try await attestation.initialize()

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

            // Stage 3: upload media blobs (if any)
            var embed: [String: Any]? = nil
            var uploadedImageURLs: [EmbedImageView] = []
            if capturedVideo != nil || !capturedPhotos.isEmpty {
                publishStage = .uploadingMedia
            }

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

            // Stage 4: publish post + proof to AT Protocol
            publishStage = .publishing
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

            // Capture the entry's stats before the counters reset
            lastEntry = SealedEntry(
                uri: result.uri,
                keystrokes: keystrokeCount,
                words: text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count,
                date: Date()
            )

            // Reset for next post
            postText = ""
            keystrokeCount = 0
            violationCount = 0
            deletionCount = 0
            capturedPhotos = []
            capturedVideo = nil
            videoProcessingStatus = nil
            isPublishing = false

            // Stage 5: sealed. The ceremony overlay shows the result and the
            // streak; the user chooses where to go next — no tab teleporting.
            writingStreak = WritingStreak.recordPublish()
            publishStage = .sealed(uri: result.uri)
            return
        } catch {
            publishError = error.localizedDescription
            videoProcessingStatus = nil
            publishStage = nil
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
                // Keep only *recent* posts search hasn't indexed yet (the
                // just-published optimistic insert). Older cache-only posts have
                // simply aged out of the feed — pinning them on top forever made
                // the feed look frozen.
                let indexingGracePeriod = Date().addingTimeInterval(-15 * 60)
                let iso = ISO8601DateFormatter()
                let optimistic = verifiedPosts.filter { post in
                    guard !fetchedURIs.contains(post.uri) else { return false }
                    guard let created = iso.date(from: post.createdAt) else { return false }
                    return created > indexingGracePeriod
                }
                verifiedPosts = optimistic + result.posts
                feedCursor = result.cursor
                FeedCache.save(verifiedPosts, key: "verified")
            }
            verifiedFeedError = nil
        } catch {
            verifiedFeedError = Self.friendlyNetworkMessage(for: error)
        }

        if isFirstLoad { isFeedLoading = false }
    }

    private var isLoadingMoreFeed = false
    private var isLoadingMoreTimeline = false
    private var isLoadingMoreFollowing = false

    /// Append a page of posts, skipping any URI already in the list. Duplicate
    /// IDs in a SwiftUI ForEach are undefined behavior (blank rows, broken
    /// scrolling), and overlapping pages / reposts make them common.
    private static func appendUnique<T: Identifiable>(_ newItems: [T], to items: inout [T]) {
        var seen = Set(items.map { "\($0.id)" })
        for item in newItems where seen.insert("\(item.id)").inserted {
            items.append(item)
        }
    }

    func loadMoreFeed() async {
        guard let cursor = feedCursor, !isLoadingMoreFeed else { return }
        isLoadingMoreFeed = true
        defer { isLoadingMoreFeed = false }

        do {
            let result = try await atproto.fetchVerifiedFeed(cursor: cursor)
            Self.appendUnique(result.posts, to: &verifiedPosts)
            // An empty page or unchanged cursor means the end — clearing the
            // cursor stops the infinite-spinner retrigger loop.
            feedCursor = (result.posts.isEmpty || result.cursor == cursor) ? nil : result.cursor
        } catch {
            print("[Feed] Error loading more: \(error)")
        }
    }

    // MARK: - Timeline (For You / Discover Feed)

    func loadTimeline() async {
        isTimelineLoading = true

        do {
            let result = try await atproto.fetchTimeline(cursor: nil)
            timelinePosts = result.posts
            timelineCursor = result.cursor
            FeedCache.save(timelinePosts, key: "timeline")
            timelineFeedError = nil
        } catch {
            timelineFeedError = Self.friendlyNetworkMessage(for: error)
        }

        isTimelineLoading = false
    }

    func loadMoreTimeline() async {
        guard let cursor = timelineCursor, !isLoadingMoreTimeline else { return }
        isLoadingMoreTimeline = true
        defer { isLoadingMoreTimeline = false }

        do {
            let result = try await atproto.fetchTimeline(cursor: cursor)
            Self.appendUnique(result.posts, to: &timelinePosts)
            timelineCursor = (result.posts.isEmpty || result.cursor == cursor) ? nil : result.cursor
        } catch {
            print("[Timeline] Error loading more: \(error)")
        }
    }

    // MARK: - Following Timeline (Authenticated)

    func loadFollowing() async {
        isFollowingLoading = true

        do {
            let result = try await atproto.fetchFollowingTimeline(cursor: nil)
            followingPosts = result.posts
            followingCursor = result.cursor
            FeedCache.save(followingPosts, key: "following")
            followingFeedError = nil
        } catch {
            followingFeedError = Self.friendlyNetworkMessage(for: error)
        }

        isFollowingLoading = false
    }

    /// Translate a feed-load failure into a short, human-readable banner message.
    static func friendlyNetworkMessage(for error: Error) -> String {
        if let atError = error as? ATProtoError {
            switch atError {
            case .pdsUnreachable(let host):
                return "Can't reach your server (\(host))"
            case .sessionExpired:
                return "Session expired — sign in again"
            case .notLoggedIn:
                return "Sign in to load this feed"
            default:
                break
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "No internet connection"
            case .timedOut:
                return "Server not responding"
            case .cannotConnectToHost, .cannotFindHost:
                return "Can't reach the server — it may be offline"
            default:
                return "Network error — pull to retry"
            }
        }
        return "Couldn't update feed — pull to retry"
    }

    func loadMoreFollowing() async {
        guard let cursor = followingCursor, !isLoadingMoreFollowing else { return }
        isLoadingMoreFollowing = true
        defer { isLoadingMoreFollowing = false }

        do {
            let result = try await atproto.fetchFollowingTimeline(cursor: cursor)
            Self.appendUnique(result.posts, to: &followingPosts)
            followingCursor = (result.posts.isEmpty || result.cursor == cursor) ? nil : result.cursor
        } catch {
            print("[Following] Error loading more: \(error)")
        }
    }

}

// MARK: - Writing Streak

/// Consecutive-day writing streak, stored in UserDefaults. A day counts when
/// at least one verified post is published.
enum WritingStreak {
    private static let countKey = "sw_streak_count"
    private static let lastDayKey = "sw_streak_last_day"

    private static func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// The streak as of `date`: yesterday's streak still counts (today isn't
    /// over), anything older is broken.
    static func current(on date: Date = Date()) -> Int {
        guard let lastDay = UserDefaults.standard.string(forKey: lastDayKey) else { return 0 }
        let today = dayString(date)
        let yesterday = dayString(date.addingTimeInterval(-86_400))
        guard lastDay == today || lastDay == yesterday else { return 0 }
        return UserDefaults.standard.integer(forKey: countKey)
    }

    /// Record a successful publish and return the updated streak.
    @discardableResult
    static func recordPublish(on date: Date = Date()) -> Int {
        let today = dayString(date)
        let yesterday = dayString(date.addingTimeInterval(-86_400))
        let lastDay = UserDefaults.standard.string(forKey: lastDayKey)

        let newCount: Int
        if lastDay == today {
            newCount = max(UserDefaults.standard.integer(forKey: countKey), 1)
        } else if lastDay == yesterday {
            newCount = UserDefaults.standard.integer(forKey: countKey) + 1
        } else {
            newCount = 1
        }

        UserDefaults.standard.set(newCount, forKey: countKey)
        UserDefaults.standard.set(today, forKey: lastDayKey)
        return newCount
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

    /// Remove all cached feeds (e.g. on sign-out).
    static func clearAll() {
        for key in ["verified", "following", "timeline"] {
            try? FileManager.default.removeItem(at: url(for: key))
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
