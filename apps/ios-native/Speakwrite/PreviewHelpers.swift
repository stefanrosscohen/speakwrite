#if DEBUG
import SwiftUI

// MARK: - Preview AppViewModel

extension AppViewModel {
    /// Creates a fully configured AppViewModel for SwiftUI previews.
    static var preview: AppViewModel {
        let vm = AppViewModel()
        vm.atproto.configureForPreview()
        vm.myProfile = .preview
        vm.verifiedPosts = VerifiedPost.previewList
        vm.timelinePosts = TimelinePost.previewList
        vm.followingPosts = TimelinePost.previewList
        return vm
    }

    /// Preview with empty feeds (loading/empty states).
    static var previewEmpty: AppViewModel {
        let vm = AppViewModel()
        vm.atproto.configureForPreview()
        vm.myProfile = .preview
        return vm
    }

    /// Preview in logged-out state.
    static var previewLoggedOut: AppViewModel {
        AppViewModel()
    }
}

// MARK: - Mock Authors

extension PostAuthor {
    static let alice = PostAuthor(
        did: "did:plc:alice123",
        handle: "alice.bsky.social",
        displayName: "Alice Johnson",
        avatar: nil,
        viewer: AuthorViewer(following: "at://follow/1", followedBy: nil, muted: false, blockedBy: false)
    )

    static let bob = PostAuthor(
        did: "did:plc:bob456",
        handle: "bob.bsky.social",
        displayName: "Bob Smith",
        avatar: nil,
        viewer: AuthorViewer(following: nil, followedBy: nil, muted: false, blockedBy: false)
    )

    static let carol = PostAuthor(
        did: "did:plc:carol789",
        handle: "carol.bsky.social",
        displayName: "Carol Williams",
        avatar: nil,
        viewer: nil
    )
}

// MARK: - Mock Profile

extension ProfileViewDetailed {
    static let preview = ProfileViewDetailed(
        did: "did:plc:alice123",
        handle: "alice.bsky.social",
        displayName: "Alice Johnson",
        description: "Building things with code. Loves open protocols and human-verified content.",
        avatar: nil,
        banner: nil,
        followersCount: 1234,
        followsCount: 567,
        postsCount: 89,
        viewer: ProfileViewer(following: nil, followedBy: nil, muted: false, blockedBy: false)
    )

    static let previewOther = ProfileViewDetailed(
        did: "did:plc:bob456",
        handle: "bob.bsky.social",
        displayName: "Bob Smith",
        description: "Open source developer. AT Protocol enthusiast.",
        avatar: nil,
        banner: nil,
        followersCount: 5678,
        followsCount: 234,
        postsCount: 456,
        viewer: ProfileViewer(following: "at://follow/1", followedBy: nil, muted: false, blockedBy: false)
    )
}

// MARK: - Mock Posts

extension VerifiedPost {
    static let preview = VerifiedPost(
        uri: "at://did:plc:alice123/app.bsky.feed.post/3abc123",
        cid: "bafyreiabc123",
        author: .alice,
        text: "Just shipped a new feature! Human-verified posting is now live on Speakwrite. Every post cryptographically proves a human typed it.",
        createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600)),
        likeCount: 42,
        repostCount: 12,
        replyCount: 5,
        viewer: PostViewer(like: nil, repost: nil),
        images: nil,
        videoURL: nil,
        videoThumbnail: nil
    )

    static let previewLiked = VerifiedPost(
        uri: "at://did:plc:bob456/app.bsky.feed.post/3def456",
        cid: "bafyreidef456",
        author: .bob,
        text: "The AT Protocol is the future of social networking. Decentralized, open, and user-owned.",
        createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7200)),
        likeCount: 128,
        repostCount: 34,
        replyCount: 18,
        viewer: PostViewer(like: "at://like/1", repost: nil),
        images: nil,
        videoURL: nil,
        videoThumbnail: nil
    )

    static let previewShort = VerifiedPost(
        uri: "at://did:plc:carol789/app.bsky.feed.post/3ghi789",
        cid: "bafyreighi789",
        author: .carol,
        text: "Hello, world!",
        createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-300)),
        likeCount: 3,
        repostCount: 0,
        replyCount: 1,
        viewer: nil,
        images: nil,
        videoURL: nil,
        videoThumbnail: nil
    )

    static let previewList: [VerifiedPost] = [.preview, .previewLiked, .previewShort]
}

extension TimelinePost {
    static let preview = TimelinePost(
        uri: "at://did:plc:alice123/app.bsky.feed.post/3abc123",
        cid: "bafyreiabc123",
        author: .alice,
        text: "Working on something exciting today. Can't wait to share it with everyone!",
        createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-1800)),
        likeCount: 15,
        repostCount: 3,
        replyCount: 7,
        isVerified: true,
        viewer: PostViewer(like: nil, repost: nil),
        repostedBy: nil,
        images: nil,
        videoURL: nil,
        videoThumbnail: nil
    )

    static let previewReposted = TimelinePost(
        uri: "at://did:plc:bob456/app.bsky.feed.post/3def456",
        cid: "bafyreidef456",
        author: .bob,
        text: "Great discussion happening about open protocols and the future of the social web.",
        createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-5400)),
        likeCount: 89,
        repostCount: 22,
        replyCount: 14,
        isVerified: false,
        viewer: PostViewer(like: "at://like/1", repost: nil),
        repostedBy: "Carol Williams",
        images: nil,
        videoURL: nil,
        videoThumbnail: nil
    )

    static let previewList: [TimelinePost] = [.preview, .previewReposted]
}

// MARK: - Mock PostNavigation

extension PostNavigation {
    static let preview = PostNavigation(
        uri: "at://did:plc:alice123/app.bsky.feed.post/3abc123",
        cid: "bafyreiabc123",
        authorHandle: "alice.bsky.social",
        authorDID: "did:plc:alice123",
        authorAvatar: nil,
        authorDisplayName: "Alice Johnson",
        text: "Just shipped a new feature! Human-verified posting is now live on Speakwrite. Every post cryptographically proves a human typed it.",
        createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600)),
        likeCount: 42,
        repostCount: 12,
        replyCount: 5,
        viewerLike: nil,
        viewerRepost: nil,
        isVerified: true,
        images: nil,
        videoURL: nil,
        videoThumbnail: nil
    )
}

// MARK: - Mock ThreadReply

extension ThreadReply {
    static let preview = ThreadReply(
        uri: "at://did:plc:bob456/app.bsky.feed.post/3reply1",
        cid: "bafyreireply1",
        authorDID: "did:plc:bob456",
        authorHandle: "bob.bsky.social",
        authorDisplayName: "Bob Smith",
        authorAvatar: nil,
        text: "This is amazing! Great work on the verification system.",
        createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-1200)),
        likeCount: 5,
        repostCount: 1,
        replyCount: 0
    )

    static let previewList: [ThreadReply] = [
        .preview,
        ThreadReply(
            uri: "at://did:plc:carol789/app.bsky.feed.post/3reply2",
            cid: "bafyreireply2",
            authorDID: "did:plc:carol789",
            authorHandle: "carol.bsky.social",
            authorDisplayName: "Carol Williams",
            authorAvatar: nil,
            text: "How does the App Attest verification work under the hood?",
            createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-600)),
            likeCount: 2,
            repostCount: 0,
            replyCount: 1
        ),
    ]
}

// MARK: - Mock ProfileViewBasic (for search)

extension ProfileViewBasic {
    static let previewList: [ProfileViewBasic] = [
        ProfileViewBasic(did: "did:plc:alice123", handle: "alice.bsky.social", displayName: "Alice Johnson", avatar: nil),
        ProfileViewBasic(did: "did:plc:bob456", handle: "bob.bsky.social", displayName: "Bob Smith", avatar: nil),
        ProfileViewBasic(did: "did:plc:carol789", handle: "carol.bsky.social", displayName: "Carol Williams", avatar: nil),
    ]
}
#endif
