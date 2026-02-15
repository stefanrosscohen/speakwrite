import Foundation
import SwiftData

/// Top-level app state. Replaces Zustand store from the web app.
@Observable
@MainActor
final class AppViewModel {
    let attestation = DeviceAttestationService()
    var atproto: ATProtoService
    var sessionService: SessionService?
    var proofService: ProofService

    // Navigation — default to feed for preview
    var selectedTab: AppTab = .timeline

    // Own profile (loaded after login / session restore)
    var myProfile: ProfileViewDetailed?

    // Compose state
    var postText: String = ""
    var isPublishing: Bool = false
    var publishError: String?
    var lastPublishedURI: String?

    // Verified feed state
    var verifiedPosts: [VerifiedPost] = []
    var feedCursor: String?
    var isFeedLoading: Bool = false

    // Timeline feed state (normal Bluesky)
    var timelinePosts: [TimelinePost] = []
    var timelineCursor: String?
    var isTimelineLoading: Bool = false

    enum AppTab: Hashable {
        case timeline
        case verified
        case compose
        case settings
    }

    init() {
        self.atproto = ATProtoService()
        self.proofService = ProofService(attestation: attestation)
    }

    func setupSession(modelContext: ModelContext) {
        sessionService = SessionService(modelContext: modelContext, attestation: attestation)
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

    func startWriting() async {
        guard let session = sessionService else { return }
        do {
            try await session.startSession()
        } catch {
            publishError = error.localizedDescription
        }
    }

    func publish() async {
        guard let session = sessionService,
              let document = session.currentDocument else { return }

        isPublishing = true
        publishError = nil

        do {
            // End session (triggers final checkpoint)
            try await session.endSession()

            // Export proof bundle
            let bundle = try await proofService.exportProofBundle(
                content: postText,
                document: document,
                commitments: session.commitments,
                keystrokeCount: session.keystrokeCount
            )

            // Publish to AT Protocol
            let result = try await atproto.publishProofPost(bundle: bundle, postText: postText)
            lastPublishedURI = result.uri

            // Reset for next post
            postText = ""
        } catch {
            publishError = error.localizedDescription
        }

        isPublishing = false
    }

    // MARK: - Verified Feed

    func loadFeed() async {
        isFeedLoading = true

        do {
            let result = try await atproto.fetchVerifiedFeed(cursor: feedCursor)
            verifiedPosts = result.posts
            feedCursor = result.cursor
        } catch {
            // Silently fail for feed load
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

    // MARK: - Timeline (Normal Bluesky Feed)

    func loadTimeline() async {
        isTimelineLoading = true

        do {
            let result = try await atproto.fetchTimeline(cursor: nil)
            timelinePosts = result.posts
            timelineCursor = result.cursor
        } catch {
            // Silently fail
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
}
