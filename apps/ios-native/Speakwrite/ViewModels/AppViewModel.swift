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

    /// Start a writing session if one isn't already active.
    /// Called when the user taps the Compose tab — triggers Face ID once.
    func ensureSessionReady() async {
        guard let session = sessionService, !session.sessionActive else { return }
        do {
            try await session.startSessionFromTabSelection()
        } catch {
            print("[Session] Could not start session: \(error)")
        }
    }

    func publish() async {
        guard let session = sessionService else {
            publishError = "Session not available."
            return
        }

        // Session starts via Face ID on Compose tab selection. If the user somehow
        // hits Publish without a session, start one now as a fallback.
        if !session.sessionActive {
            do {
                try await session.startSession()
            } catch {
                publishError = "Could not start session: \(error.localizedDescription)"
                return
            }
        }

        guard let document = session.currentDocument else {
            publishError = "No active writing session."
            return
        }

        isPublishing = true
        publishError = nil

        do {
            // End session (final checkpoint, keeps biometric context for signing)
            try await session.endSession()

            // Export proof bundle (signs with SE key)
            let bundle = try await proofService.exportProofBundle(
                content: postText,
                document: document,
                commitments: session.commitments,
                keystrokeCount: session.keystrokeCount
            )

            // Invalidate biometric context — signing is done
            await session.finalizeSession()

            // Publish to AT Protocol
            let result = try await atproto.publishProofPost(bundle: bundle, postText: postText)
            lastPublishedURI = result.uri

            // Reset for next post
            postText = ""

            // Flash "Published" for 2 seconds then reset
            isPublishing = false
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            lastPublishedURI = nil
            return
        } catch {
            await session.finalizeSession()
            publishError = error.localizedDescription
        }

        isPublishing = false
    }

    // MARK: - Verified Feed

    func loadFeed() async {
        isFeedLoading = true

        do {
            let result = try await atproto.fetchVerifiedFeed(cursor: nil)
            // Only replace posts if we got results — prevents crash when
            // pull-to-refresh returns empty (view flips from ScrollView to
            // ContentUnavailableView mid-refresh, causing layout crash).
            if !result.posts.isEmpty || verifiedPosts.isEmpty {
                verifiedPosts = result.posts
                feedCursor = result.cursor
            }
            print("[Feed] Loaded \(result.posts.count) verified posts")
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
