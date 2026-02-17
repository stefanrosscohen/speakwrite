import CryptoKit
import Foundation

/// Top-level app state. Replaces Zustand store from the web app.
@Observable
@MainActor
final class AppViewModel: InputRestrictedDelegate {
    let attestation = DeviceAttestationService()
    let verification = VerificationService()
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

    enum AppTab: Hashable {
        case timeline
        case verified
        case compose
        case settings
    }

    init() {
        self.atproto = ATProtoService()
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
        guard !text.isEmpty else {
            publishError = "Post cannot be empty."
            return
        }

        isPublishing = true
        publishError = nil

        do {
            // Initialize attestation (generates + attests App Attest key if needed)
            let keyId = try await attestation.initialize()

            // Compute content hash (SHA-256 raw bytes — App Attest needs Data)
            let contentHashData = Data(SHA256.hash(data: Data(text.utf8)))
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
                appId: Bundle.main.bundleIdentifier ?? "io.speakwrite.app"
            )

            // Publish to AT Protocol
            let result = try await atproto.publishAttestedPost(text: text, attestation: record)
            lastPublishedURI = result.uri

            // Reset for next post
            postText = ""
            keystrokeCount = 0
            violationCount = 0
            isPublishing = false

            // Navigate to feed
            selectedTab = .timeline
            lastPublishedURI = nil
            return
        } catch {
            publishError = error.localizedDescription
        }

        isPublishing = false
    }

    // MARK: - Verified Feed

    func loadFeed() async {
        isFeedLoading = true

        do {
            let result = try await atproto.fetchVerifiedFeed(cursor: nil)
            if !result.posts.isEmpty || verifiedPosts.isEmpty {
                verifiedPosts = result.posts
                feedCursor = result.cursor
            }
        } catch {
            print("[Feed] Error loading verified feed: \(error)")
        }

        isFeedLoading = false
    }

    func loadMoreFeed() async {
        guard let cursor = feedCursor else { return }

        do {
            let result = try await atproto.fetchVerifiedFeed(cursor: cursor)
            verifiedPosts.append(contentsOf: result.posts)
            feedCursor = result.cursor
        } catch {
            // Silently fail
        }
    }

    // MARK: - Timeline (For You / Discover Feed)

    func loadTimeline() async {
        isTimelineLoading = true

        do {
            let result = try await atproto.fetchTimeline(cursor: nil)
            timelinePosts = result.posts
            timelineCursor = result.cursor
        } catch {
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
            // Silently fail
        }
    }

    // MARK: - Following Timeline (Authenticated)

    func loadFollowing() async {
        isFollowingLoading = true

        do {
            let result = try await atproto.fetchFollowingTimeline(cursor: nil)
            followingPosts = result.posts
            followingCursor = result.cursor
        } catch {
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
            // Silently fail
        }
    }
}
