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
    var repostAttribution: String? { get }
    var images: [EmbedImageView]? { get }
    var videoURL: String? { get }
    var videoThumbnail: String? { get }
}

extension VerifiedPost: PostDisplayable {
    var showVerifiedBadge: Bool { true }
    var repostAttribution: String? { nil }
}

extension TimelinePost: PostDisplayable {
    var showVerifiedBadge: Bool { isVerified }
    var repostAttribution: String? { repostedBy }
}

// MARK: - Rich Text (Mentions + URLs)

/// Build an AttributedString with @mentions and URLs as tappable links.
func mentionHighlightedText(_ text: String) -> AttributedString {
    var result = AttributedString(text)

    // Highlight @mentions → in-app profile navigation
    if let mentionPattern = try? NSRegularExpression(
        pattern: "@([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.)+[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?"
    ) {
        let matches = mentionPattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            guard let range = Range(match.range, in: text),
                  let attrRange = Range(range, in: result) else { continue }
            let handle = String(text[range]).dropFirst()
            result[attrRange].foregroundColor = Theme.accent
            if let url = URL(string: "speakwrite://profile/\(handle)") {
                result[attrRange].link = url
            }
        }
    }

    // Highlight URLs → open in Safari
    if let urlPattern = try? NSRegularExpression(
        pattern: "https?://[^\\s<>\"')\\]]+|www\\.[^\\s<>\"')\\]]+",
        options: .caseInsensitive
    ) {
        let matches = urlPattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            guard let range = Range(match.range, in: text),
                  let attrRange = Range(range, in: result) else { continue }
            var urlString = String(text[range])
            if urlString.hasPrefix("www.") { urlString = "https://\(urlString)" }
            // Trim trailing punctuation that's likely not part of the URL
            while urlString.hasSuffix(".") || urlString.hasSuffix(",") || urlString.hasSuffix(";") {
                urlString = String(urlString.dropLast())
            }
            result[attrRange].foregroundColor = Theme.accent
            if let url = URL(string: urlString) {
                result[attrRange].link = url
            }
        }
    }

    return result
}

// MARK: - PostRow (Bluesky-style)

/// Bluesky-style post row.
/// - Avatar tap → profile
/// - Header tap → profile
/// - Body tap → post detail with replies
/// - Repost → action sheet with Repost / Quote Post
struct PostRow<Post: PostDisplayable>: View {
    let post: Post
    var hideFollowButton: Bool = false
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
    @State private var showProofSheet = false
    @State private var isFollowingAuthor = false

    private var verificationStatus: VerificationStatus {
        viewModel.verification.status(for: post.uri)
    }

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
            isVerified: verificationStatus == .verified,
            images: post.images,
            videoURL: post.videoURL, videoThumbnail: post.videoThumbnail
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Repost attribution
            if let repostedBy = post.repostAttribution {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.system(size: 12))
                    Text("Reposted by \(repostedBy)")
                        .font(.system(size: 13))
                }
                .foregroundStyle(Theme.textTertiary(colorScheme))
                .padding(.leading, 52) // Align with post text (avatar + spacing)
                .padding(.bottom, 2)
            }

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
                        VStack(alignment: .leading, spacing: 8) {
                            if !post.text.isEmpty {
                                Text(mentionHighlightedText(post.text))
                                    .font(.system(size: 15))
                                    .foregroundStyle(Theme.textPrimary(colorScheme))
                                    .lineLimit(12)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            if let images = post.images, !images.isEmpty {
                                PostImagesView(images: images, interactive: false)
                            } else if let videoURL = post.videoURL, let thumb = post.videoThumbnail {
                                PostVideoView(thumbnailURL: thumb, playlistURL: videoURL)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    // Engagement row
                    engagementRow
                        .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 10)
        .accessibilityIdentifier("post-row")
        .onAppear { syncEngagementState() }
        .task {
            // Only posts that claim a Speakwrite proof are worth verifying —
            // running the proof pipeline for every timeline author hammers
            // their PDSes and always comes back empty.
            if post.showVerifiedBadge {
                viewModel.verification.verify(postUri: post.uri, postText: post.text, authorDID: post.author.did)
            }
        }
        .sheet(isPresented: $showProofSheet) {
            ProofDetailSheet(
                status: verificationStatus,
                authorHandle: post.author.handle,
                postUri: post.uri,
                onRetry: {
                    viewModel.verification.verify(
                        postUri: post.uri, postText: post.text,
                        authorDID: post.author.did, force: true
                    )
                }
            )
        }
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
        isFollowingAuthor = post.author.viewer?.following != nil
    }

    // MARK: - Header

    private var headerLine: some View {
        HStack(spacing: 0) {
            if let displayName = post.author.displayName, !displayName.isEmpty {
                Text(displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary(colorScheme))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            if post.showVerifiedBadge {
                Button {
                    showProofSheet = true
                } label: {
                    VerificationBadge(status: verificationStatus)
                        .padding(.leading, 2)
                }
                .buttonStyle(.plain)
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

            // Inline follow button — only when viewer state is available (authenticated feed)
            if !hideFollowButton && !isFollowingAuthor && post.author.viewer != nil && post.author.did != viewModel.atproto.did {
                Spacer(minLength: 4)
                Button {
                    Task { await followAuthor() }
                } label: {
                    Text("Follow")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.accent))
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .fixedSize()
            }
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

    private func notifyFailure() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    private func toggleLike() async {
        if isLiked, let uri = likeUri {
            isLiked = false; localLikeCount -= 1; likeUri = nil
            do {
                try await viewModel.atproto.unlikePost(likeUri: uri)
            } catch {
                isLiked = true; localLikeCount += 1; likeUri = uri
                notifyFailure()
            }
        } else {
            isLiked = true; localLikeCount += 1
            do {
                likeUri = try await viewModel.atproto.likePost(uri: post.uri, cid: post.cid)
            } catch {
                isLiked = false; localLikeCount -= 1
                notifyFailure()
            }
        }
    }

    private func toggleRepost() async {
        if isReposted, let uri = repostUri {
            isReposted = false; localRepostCount -= 1; repostUri = nil
            do {
                try await viewModel.atproto.unrepost(repostUri: uri)
            } catch {
                isReposted = true; localRepostCount += 1; repostUri = uri
                notifyFailure()
            }
        } else {
            isReposted = true; localRepostCount += 1
            do {
                repostUri = try await viewModel.atproto.repost(uri: post.uri, cid: post.cid)
            } catch {
                isReposted = false; localRepostCount -= 1
                notifyFailure()
            }
        }
    }

    private func followAuthor() async {
        isFollowingAuthor = true
        do {
            _ = try await viewModel.atproto.follow(did: post.author.did)
        } catch {
            isFollowingAuthor = false
            notifyFailure()
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

#if DEBUG
#Preview("Verified Post") {
    NavigationStack {
        PostRow(post: VerifiedPost.preview)
            .padding(.horizontal)
    }
    .environment(AppViewModel.preview)
}

#Preview("Timeline Post") {
    NavigationStack {
        PostRow(post: TimelinePost.previewReposted)
            .padding(.horizontal)
    }
    .environment(AppViewModel.preview)
}
#endif
