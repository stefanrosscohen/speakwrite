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

    // Navigation — default to feed for preview
    var selectedTab: AppTab = .timeline

    // Compose is a modal sheet, reachable from every tab
    var showCompose = false

    // Own profile (loaded after login / session restore)
    var myProfile: ProfileViewDetailed?

    // Compose state
    var postText: String = ""
    var isPublishing: Bool = false
    var publishError: String?
    /// Set when the post published but something non-fatal went wrong (e.g. proof record failed)
    var publishWarning: String?
    var lastPublishedURI: String?
    var keystrokeCount: Int = 0
    var violationCount: Int = 0
    /// Incremented to tell the input-restricted editor to reset its internal counters
    var composeResetSignal: Int = 0

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
    var feedError: String?

    // Timeline feed state (For You — discover feed)
    var timelinePosts: [TimelinePost] = []
    var timelineCursor: String?
    var isTimelineLoading: Bool = false
    var timelineError: String?

    // Following feed state (authenticated following timeline)
    var followingPosts: [TimelinePost] = []
    var followingCursor: String?
    var isFollowingLoading: Bool = false
    var followingError: String?

    // Notifications state
    var notifications: [AppNotification] = []
    var notificationsCursor: String?
    var isNotificationsLoading: Bool = false
    var notificationsError: String?
    var unreadNotificationCount: Int = 0
    /// Hydrated subject posts (the post that was liked/reposted), keyed by URI
    var notificationSubjects: [String: FeedPost] = [:]

    enum AppTab: Hashable {
        case timeline
        case verified
        case notifications
        case profile
    }

    private static let draftKey = "sw_compose_draft"

    init() {
        self.atproto = ATProtoService()
        FeedCache.migrateIfNeeded()
        // Restore cached feeds instantly
        verifiedPosts = FeedCache.load("verified") ?? []
        followingPosts = FeedCache.load("following") ?? []
        timelinePosts = FeedCache.load("timeline") ?? []
        // Restore any unfinished draft
        postText = UserDefaults.standard.string(forKey: Self.draftKey) ?? ""
    }

    // MARK: - InputRestrictedDelegate

    nonisolated func textDidChange(_ text: String) {
        Task { @MainActor in
            self.postText = text
            // Persist the draft so a force-quit doesn't lose typed work
            UserDefaults.standard.set(text, forKey: Self.draftKey)
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
            if !result.proofCreated {
                publishWarning = "Post published, but the verification proof couldn't be saved. This post won't show as verified."
            }

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
            FeedCache.save(verifiedPosts, key: "verified")

            // Reset for next post. lastPublishedURI stays set so the compose
            // sheet can show its success state before dismissing.
            clearDraft()
        } catch {
            publishError = error.localizedDescription
            videoProcessingStatus = nil
        }

        isPublishing = false
    }

    /// Reset all compose state (draft text, media, counters, errors).
    func clearDraft() {
        postText = ""
        keystrokeCount = 0
        violationCount = 0
        composeResetSignal += 1
        capturedPhotos = []
        capturedVideo = nil
        videoProcessingStatus = nil
        publishError = nil
        UserDefaults.standard.removeObject(forKey: Self.draftKey)
    }

    // MARK: - Reply Flow (Attested)

    func publishReply(
        text: String,
        parentUri: String,
        parentCid: String,
        rootUri: String? = nil,
        rootCid: String? = nil,
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

        // 8. Publish with reply field + embed. The thread root is the parent's
        // own root when replying to a reply; the parent itself otherwise.
        let _ = try await atproto.publishAttestedPost(
            text: text,
            attestation: record,
            embed: embed,
            reply: ATProtoService.ReplyRefs(
                parentUri: parentUri,
                parentCid: parentCid,
                rootUri: rootUri ?? parentUri,
                rootCid: rootCid ?? parentCid
            )
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
            // Keep only *our own, recent* posts that search hasn't indexed yet —
            // anything else pinned above the fresh results is stale cache.
            let fetchedURIs = Set(result.posts.map(\.uri))
            let myDID = atproto.did
            let optimistic = verifiedPosts.filter { post in
                !fetchedURIs.contains(post.uri)
                    && post.author.did == myDID
                    && Self.isRecent(post.createdAt, within: 3600)
            }
            verifiedPosts = optimistic + result.posts
            feedCursor = result.cursor
            feedError = nil
            FeedCache.save(verifiedPosts, key: "verified")
        } catch {
            feedError = error.localizedDescription
        }

        if isFirstLoad { isFeedLoading = false }
    }

    func loadMoreFeed() async {
        guard let cursor = feedCursor else { return }

        do {
            let result = try await atproto.fetchVerifiedFeed(cursor: cursor)
            let existing = Set(verifiedPosts.map(\.uri))
            verifiedPosts.append(contentsOf: result.posts.filter { !existing.contains($0.uri) })
            feedCursor = result.cursor
        } catch {
            // Pagination failures are non-fatal; the user can scroll again
        }
    }

    /// Whether an ISO 8601 timestamp is within `seconds` of now.
    private static func isRecent(_ isoString: String, within seconds: TimeInterval) -> Bool {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: isoString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: isoString)
        }
        guard let date else { return false }
        return -date.timeIntervalSinceNow < seconds
    }

    // MARK: - Timeline (For You / Discover Feed)

    func loadTimeline() async {
        // Only block the UI with a spinner when there's nothing cached to show
        let isFirstLoad = timelinePosts.isEmpty
        if isFirstLoad { isTimelineLoading = true }

        do {
            let result = try await atproto.fetchTimeline(cursor: nil)
            timelinePosts = result.posts
            timelineCursor = result.cursor
            timelineError = nil
            FeedCache.save(timelinePosts, key: "timeline")
        } catch {
            timelineError = error.localizedDescription
        }

        if isFirstLoad { isTimelineLoading = false }
    }

    func loadMoreTimeline() async {
        guard let cursor = timelineCursor else { return }

        do {
            let result = try await atproto.fetchTimeline(cursor: cursor)
            let existing = Set(timelinePosts.map(\.uri))
            timelinePosts.append(contentsOf: result.posts.filter { !existing.contains($0.uri) })
            timelineCursor = result.cursor
        } catch {
            // Pagination failures are non-fatal
        }
    }

    // MARK: - Following Timeline (Authenticated)

    func loadFollowing() async {
        let isFirstLoad = followingPosts.isEmpty
        if isFirstLoad { isFollowingLoading = true }

        do {
            let result = try await atproto.fetchFollowingTimeline(cursor: nil)
            followingPosts = result.posts
            followingCursor = result.cursor
            followingError = nil
            FeedCache.save(followingPosts, key: "following")
        } catch {
            followingError = error.localizedDescription
        }

        if isFirstLoad { isFollowingLoading = false }
    }

    func loadMoreFollowing() async {
        guard let cursor = followingCursor else { return }

        do {
            let result = try await atproto.fetchFollowingTimeline(cursor: cursor)
            let existing = Set(followingPosts.map(\.uri))
            followingPosts.append(contentsOf: result.posts.filter { !existing.contains($0.uri) })
            followingCursor = result.cursor
        } catch {
            // Pagination failures are non-fatal
        }
    }

    // MARK: - Notifications

    func loadNotifications() async {
        guard atproto.isLoggedIn else { return }
        let isFirstLoad = notifications.isEmpty
        if isFirstLoad { isNotificationsLoading = true }
        notificationsError = nil

        do {
            let result = try await atproto.listNotifications()
            notifications = result.notifications
            notificationsCursor = result.cursor
            await hydrateNotificationSubjects(for: result.notifications)
            // Viewing the list marks everything seen
            try? await atproto.markNotificationsSeen()
            unreadNotificationCount = 0
        } catch {
            notificationsError = error.localizedDescription
        }

        if isFirstLoad { isNotificationsLoading = false }
    }

    func loadMoreNotifications() async {
        guard let cursor = notificationsCursor else { return }
        do {
            let result = try await atproto.listNotifications(cursor: cursor)
            let existing = Set(notifications.map(\.uri))
            let fresh = result.notifications.filter { !existing.contains($0.uri) }
            notifications.append(contentsOf: fresh)
            notificationsCursor = result.cursor
            await hydrateNotificationSubjects(for: fresh)
        } catch {
            // Pagination failures are non-fatal
        }
    }

    /// Refresh the unread badge count (cheap; called on foreground / tab switches).
    func refreshUnreadCount() async {
        guard atproto.isLoggedIn else { return }
        if let count = try? await atproto.getUnreadNotificationCount() {
            unreadNotificationCount = count
        }
    }

    /// Fetch the posts notifications refer to, so rows can show a snippet and
    /// navigate: the liked/reposted subject for likes/reposts, and the
    /// notification's own post for replies/mentions/quotes.
    private func hydrateNotificationSubjects(for notifs: [AppNotification]) async {
        var uris = Set<String>()
        for notif in notifs {
            if let subject = notif.reasonSubject { uris.insert(subject) }
            if ["reply", "mention", "quote"].contains(notif.reason) { uris.insert(notif.uri) }
        }
        uris.subtract(notificationSubjects.keys)
        guard !uris.isEmpty else { return }
        // getPosts caps at 25 URIs per call — chunk the request
        let sorted = Array(uris).sorted()
        for chunk in stride(from: 0, to: sorted.count, by: 25).map({ Array(sorted[$0..<min($0 + 25, sorted.count)]) }) {
            if let posts = try? await atproto.getPosts(uris: chunk) {
                for post in posts {
                    notificationSubjects[post.uri] = post
                }
            }
        }
    }

    // MARK: - Sign Out

    /// Sign out and clear every piece of per-account state, including disk caches —
    /// the next account must not see this account's feeds or draft.
    func signOut() {
        atproto.logout()
        myProfile = nil

        verifiedPosts = []
        timelinePosts = []
        followingPosts = []
        feedCursor = nil
        timelineCursor = nil
        followingCursor = nil
        feedError = nil
        timelineError = nil
        followingError = nil

        notifications = []
        notificationsCursor = nil
        notificationsError = nil
        unreadNotificationCount = 0
        notificationSubjects = [:]

        clearDraft()
        publishWarning = nil
        lastPublishedURI = nil
        showCompose = false
        selectedTab = .timeline

        FeedCache.clearAll()
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
            clearAll()
            UserDefaults.standard.set(cacheVersion, forKey: versionKey)
        }
    }

    /// Remove all cached feeds from disk (e.g. on sign-out).
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
