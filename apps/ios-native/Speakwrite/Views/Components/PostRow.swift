import SwiftUI

// MARK: - PostDisplayable Protocol

/// Unified protocol for both VerifiedPost and TimelinePost.
protocol PostDisplayable: Identifiable {
    var uri: String { get }
    var cid: String { get }
    var author: PostAuthor { get }
    var text: String { get }
    var createdAt: String { get }
    var likeCount: Int { get }
    var repostCount: Int { get }
    var replyCount: Int { get }
    var viewer: PostViewer? { get }
    var showVerifiedBadge: Bool { get }
}

extension VerifiedPost: PostDisplayable {
    var showVerifiedBadge: Bool { true }
}

extension TimelinePost: PostDisplayable {
    var showVerifiedBadge: Bool { isVerified }
}

// MARK: - PostRow (Bluesky-style)

/// Bluesky-style post row.
/// - Avatar tap → profile
/// - Header tap → profile
/// - Body tap → post detail with replies
/// - Repost → action sheet with Repost / Quote Post
struct PostRow<Post: PostDisplayable>: View {
    let post: Post
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var isLiked = false
    @State private var likeUri: String?
    @State private var localLikeCount: Int = 0
    @State private var isReposted = false
    @State private var repostUri: String?
    @State private var localRepostCount: Int = 0
    @State private var showReplySheet = false
    @State private var showRepostMenu = false
    @State private var showQuotePost = false

    /// Build a PostNavigation value for detail view navigation.
    private var postNavigation: PostNavigation {
        PostNavigation(
            uri: post.uri, cid: post.cid,
            authorHandle: post.author.handle,
            authorDID: post.author.did,
            authorAvatar: post.author.avatar,
            authorDisplayName: post.author.displayName,
            text: post.text, createdAt: post.createdAt,
            likeCount: localLikeCount, repostCount: localRepostCount,
            replyCount: post.replyCount,
            viewerLike: likeUri, viewerRepost: repostUri,
            isVerified: post.showVerifiedBadge
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Left column: avatar → profile
            NavigationLink(value: post.author.did) {
                AvatarView(
                    url: post.author.avatar,
                    handle: post.author.handle,
                    size: .medium
                )
            }
            .buttonStyle(.plain)

            // Right column
            VStack(alignment: .leading, spacing: 4) {
                // Header → profile
                NavigationLink(value: post.author.did) {
                    headerLine
                }
                .buttonStyle(.plain)

                // Post body → post detail
                NavigationLink(value: postNavigation) {
                    Text(post.text)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textPrimary(colorScheme))
                        .lineLimit(12)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.plain)

                // Engagement row
                engagementRow
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 10)
        .onAppear { syncEngagementState() }
        .sheet(isPresented: $showReplySheet) {
            ReplyView(
                replyToUri: post.uri,
                replyToCid: post.cid,
                replyToHandle: post.author.handle,
                replyToDisplayName: post.author.displayName,
                replyToAvatar: post.author.avatar,
                replyToText: post.text
            )
        }
        .confirmationDialog("", isPresented: $showRepostMenu, titleVisibility: .hidden) {
            Button(isReposted ? "Undo repost" : "Repost") {
                Task { await toggleRepost() }
            }
            Button("Quote Post") {
                showQuotePost = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showQuotePost) {
            QuotePostView(
                quotedUri: post.uri,
                quotedCid: post.cid,
                quotedHandle: post.author.handle,
                quotedDisplayName: post.author.displayName,
                quotedAvatar: post.author.avatar,
                quotedText: post.text
            )
        }
    }

    private func syncEngagementState() {
        isLiked = post.viewer?.like != nil
        likeUri = post.viewer?.like
        localLikeCount = post.likeCount
        isReposted = post.viewer?.repost != nil
        repostUri = post.viewer?.repost
        localRepostCount = post.repostCount
    }

    // MARK: - Header

    private var headerLine: some View {
        HStack(spacing: 0) {
            if let displayName = post.author.displayName, !displayName.isEmpty {
                Text(displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary(colorScheme))
                    .lineLimit(1)
                    .layoutPriority(1)
            }

            if post.showVerifiedBadge {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.accent)
                    .padding(.leading, 2)
            }

            Text(" @\(post.author.handle)")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary(colorScheme))
                .lineLimit(1)
                .truncationMode(.tail)

            Text(" · \(relativeTimeString(from: post.createdAt))")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textTertiary(colorScheme))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    // MARK: - Engagement Row

    private var engagementRow: some View {
        HStack(spacing: 0) {
            PostControlButton(icon: "bubble.left", count: post.replyCount,
                              activeColor: nil, isActive: false) {
                showReplySheet = true
            }

            Spacer(minLength: 0)

            PostControlButton(icon: "arrow.2.squarepath", count: localRepostCount,
                              activeColor: Theme.accent, isActive: isReposted) {
                showRepostMenu = true
            }

            Spacer(minLength: 0)

            PostControlButton(icon: isLiked ? "heart.fill" : "heart", count: localLikeCount,
                              activeColor: Theme.liked, isActive: isLiked) {
                Task { await toggleLike() }
            }

            Spacer(minLength: 0)

            Button { sharePost() } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.textTertiary(colorScheme))
                    .padding(5)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: 320, alignment: .leading)
    }

    // MARK: - Actions

    private func toggleLike() async {
        if isLiked, let uri = likeUri {
            isLiked = false; localLikeCount -= 1; likeUri = nil
            try? await viewModel.atproto.unlikePost(likeUri: uri)
        } else {
            isLiked = true; localLikeCount += 1
            if let uri = try? await viewModel.atproto.likePost(uri: post.uri, cid: post.cid) {
                likeUri = uri
            }
        }
    }

    private func toggleRepost() async {
        if isReposted, let uri = repostUri {
            isReposted = false; localRepostCount -= 1; repostUri = nil
            try? await viewModel.atproto.unrepost(repostUri: uri)
        } else {
            isReposted = true; localRepostCount += 1
            if let uri = try? await viewModel.atproto.repost(uri: post.uri, cid: post.cid) {
                repostUri = uri
            }
        }
    }

    private func sharePost() {
        let parts = post.uri.components(separatedBy: "/")
        if let rkey = parts.last {
            let bskyURL = "https://bsky.app/profile/\(post.author.handle)/post/\(rkey)"
            let activityVC = UIActivityViewController(activityItems: [bskyURL], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
    }
}

// MARK: - Post Control Button

private struct PostControlButton: View {
    let icon: String
    let count: Int
    let activeColor: Color?
    let isActive: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var foreground: Color {
        if isActive, let activeColor { return activeColor }
        return Theme.textTertiary(colorScheme)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                if count > 0 {
                    Text(formatCount(count))
                        .font(.system(size: 14, weight: isActive ? .semibold : .regular))
                }
            }
            .foregroundStyle(foreground)
            .padding(5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
