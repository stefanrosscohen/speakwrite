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

// MARK: - PostRow

/// Post row.
/// - Avatar / header tap → profile
/// - Body tap → post detail with replies
/// - Seal tap → proof explanation sheet
/// - Repost → action sheet with Repost / Quote Post
///
/// Post body text is serif — the human artifact. Chrome stays sans; the seal
/// and proof surfaces are the only places monospace appears.
struct PostRow<Post: PostDisplayable>: View {
    let post: Post
    var hideFollowButton: Bool = false
    @Environment(AppViewModel.self) private var viewModel

    @State private var showReplySheet = false
    @State private var showRepostMenu = false
    @State private var showQuotePost = false
    @State private var showProofDetail = false

    private var verificationStatus: VerificationStatus {
        viewModel.verification.status(for: post.uri)
    }

    // Engagement state lives in the view model (keyed by URI) so recycled
    // rows and duplicate copies of a post across feeds stay consistent.
    private var engagement: AppViewModel.EngagementOverride {
        viewModel.engagement[post.uri] ?? AppViewModel.EngagementOverride(
            isLiked: post.viewer?.like != nil,
            likeUri: post.viewer?.like,
            likeCount: post.likeCount,
            isReposted: post.viewer?.repost != nil,
            repostUri: post.viewer?.repost,
            repostCount: post.repostCount
        )
    }

    private var isFollowingAuthor: Bool {
        viewModel.followedDIDs.contains(post.author.did) || post.author.viewer?.following != nil
    }

    /// Build a PostNavigation value for detail view navigation.
    private var postNavigation: PostNavigation {
        let state = engagement
        return PostNavigation(
            uri: post.uri, cid: post.cid,
            authorHandle: post.author.handle,
            authorDID: post.author.did,
            authorAvatar: post.author.avatar,
            authorDisplayName: post.author.displayName,
            text: post.text, createdAt: post.createdAt,
            likeCount: state.likeCount, repostCount: state.repostCount,
            replyCount: post.replyCount,
            viewerLike: state.likeUri, viewerRepost: state.repostUri,
            isVerified: verificationStatus == .verified,
            images: post.images,
            videoURL: post.videoURL, videoThumbnail: post.videoThumbnail
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Repost attribution
            if let repostedBy = post.repostAttribution {
                HStack(spacing: Theme.xs) {
                    Image(systemName: "arrow.2.squarepath")
                        .font(.caption)
                    Text("Reposted by \(repostedBy)")
                        .font(Theme.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(Theme.inkTertiary)
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
                    headerLine

                    // Post body → post detail
                    NavigationLink(value: postNavigation) {
                        VStack(alignment: .leading, spacing: Theme.sm) {
                            if !post.text.isEmpty {
                                Text(mentionHighlightedText(post.text))
                                    .font(Theme.postBody)
                                    .foregroundStyle(Theme.ink)
                                    .lineSpacing(2)
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
        .task(id: post.uri) {
            // Only Speakwrite-tagged posts carry proofs — running verification
            // for every timeline post hammered plc.directory + every author's
            // PDS on each scroll.
            if post.showVerifiedBadge {
                viewModel.verification.verify(postUri: post.uri, postText: post.text, authorDID: post.author.did)
            }
        }
        .sheet(isPresented: $showProofDetail) {
            ProofDetailView(
                status: verificationStatus,
                authorHandle: post.author.handle,
                postUri: post.uri
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
            Button(engagement.isReposted ? "Undo repost" : "Repost") {
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

    // MARK: - Header

    private var headerLine: some View {
        HStack(spacing: 0) {
            // Name + handle + time → profile
            NavigationLink(value: post.author.did) {
                HStack(spacing: 0) {
                    if let displayName = post.author.displayName, !displayName.isEmpty {
                        Text(displayName)
                            .font(Theme.body.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Text(" @\(post.author.handle)")
                        .font(Theme.subhead)
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(-1)

                    Text(" · \(relativeTimeString(from: post.createdAt))")
                        .font(Theme.subhead)
                        .foregroundStyle(Theme.inkTertiary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .buttonStyle(.plain)

            // Seal — outside the profile link, tappable for proof details
            if post.showVerifiedBadge {
                SealBadge(status: verificationStatus) {
                    showProofDetail = true
                }
            }

            // Follow — its own button, not nested inside a NavigationLink
            if !hideFollowButton && !isFollowingAuthor && post.author.viewer != nil && post.author.did != viewModel.atproto.did {
                Spacer(minLength: Theme.xs)
                Button {
                    Task { await followAuthor() }
                } label: {
                    Text("Follow")
                        .font(Theme.caption.weight(.bold))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, Theme.md)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.accentFill))
                }
                .buttonStyle(.plain)
                .fixedSize()
            } else {
                Spacer(minLength: 0)
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

            PostControlButton(icon: "arrow.2.squarepath", count: engagement.repostCount,
                              activeColor: Theme.reposted, isActive: engagement.isReposted) {
                showRepostMenu = true
            }

            Spacer(minLength: 0)

            PostControlButton(icon: engagement.isLiked ? "heart.fill" : "heart", count: engagement.likeCount,
                              activeColor: Theme.liked, isActive: engagement.isLiked) {
                Task { await toggleLike() }
            }

            Spacer(minLength: 0)

            Button { sharePost() } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.body)
                    .foregroundStyle(Theme.inkTertiary)
                    .padding(5)
                    .contentShape(Rectangle())
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
        let before = engagement
        var state = before

        if before.isLiked, let uri = before.likeUri {
            state.isLiked = false
            state.likeCount = max(0, state.likeCount - 1)
            state.likeUri = nil
            viewModel.engagement[post.uri] = state
            do {
                try await viewModel.atproto.unlikePost(likeUri: uri)
            } catch {
                viewModel.engagement[post.uri] = before
                notifyFailure()
            }
        } else {
            state.isLiked = true
            state.likeCount += 1
            viewModel.engagement[post.uri] = state
            do {
                state.likeUri = try await viewModel.atproto.likePost(uri: post.uri, cid: post.cid)
                viewModel.engagement[post.uri] = state
            } catch {
                viewModel.engagement[post.uri] = before
                notifyFailure()
            }
        }
    }

    private func toggleRepost() async {
        let before = engagement
        var state = before

        if before.isReposted, let uri = before.repostUri {
            state.isReposted = false
            state.repostCount = max(0, state.repostCount - 1)
            state.repostUri = nil
            viewModel.engagement[post.uri] = state
            do {
                try await viewModel.atproto.unrepost(repostUri: uri)
            } catch {
                viewModel.engagement[post.uri] = before
                notifyFailure()
            }
        } else {
            state.isReposted = true
            state.repostCount += 1
            viewModel.engagement[post.uri] = state
            do {
                state.repostUri = try await viewModel.atproto.repost(uri: post.uri, cid: post.cid)
                viewModel.engagement[post.uri] = state
            } catch {
                viewModel.engagement[post.uri] = before
                notifyFailure()
            }
        }
    }

    private func followAuthor() async {
        viewModel.followedDIDs.insert(post.author.did)
        do {
            _ = try await viewModel.atproto.follow(did: post.author.did)
        } catch {
            viewModel.followedDIDs.remove(post.author.did)
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

    private var foreground: Color {
        if isActive, let activeColor { return activeColor }
        return Theme.inkTertiary
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.body)
                if count > 0 {
                    Text(formatCount(count))
                        .font(Theme.subhead.weight(isActive ? .semibold : .regular))
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
