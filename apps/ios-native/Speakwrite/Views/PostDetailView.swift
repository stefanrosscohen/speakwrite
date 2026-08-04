import SwiftUI

/// Full post detail view with thread/replies — shown when tapping a post in the feed.
struct PostDetailView: View {
    let nav: PostNavigation
    @Environment(AppViewModel.self) private var viewModel

    @State private var replies: [ThreadReply] = []
    @State private var isLoading = true
    @State private var threadError: String?
    @State private var showReplySheet = false

    // Engagement state for the main post
    @State private var isLiked = false
    @State private var likeUri: String?
    @State private var localLikeCount: Int = 0
    @State private var isReposted = false
    @State private var repostUri: String?
    @State private var localRepostCount: Int = 0
    @State private var showRepostMenu = false
    @State private var showQuotePost = false
    @State private var didInitEngagement = false

    /// The thread root every reply in this view belongs to: this post's own
    /// root when it's a reply, otherwise this post itself.
    private var threadRootUri: String { nav.rootUri ?? nav.uri }
    private var threadRootCid: String { nav.rootCid ?? nav.cid }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // MARK: Main post (expanded style, not compact feed style)
                mainPostView
                    .padding(.horizontal, Theme.lg)
                    .padding(.vertical, Theme.lg)

                ThemedDivider()

                // MARK: Replies
                if isLoading {
                    ProgressView("Loading replies…")
                        .tint(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.xxxl)
                } else if let error = threadError {
                    VStack(spacing: Theme.sm) {
                        Text(error)
                            .font(Theme.subhead)
                            .foregroundStyle(Theme.textSecondary)
                        Button("Retry") {
                            threadError = nil
                            Task { await loadThread() }
                        }
                        .font(Theme.monoBold)
                        .foregroundStyle(Theme.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.xxxl)
                } else if replies.isEmpty {
                    Text("No replies yet")
                        .font(Theme.subhead)
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.xxxl)
                        .accessibilityIdentifier("no-replies")
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(replies) { reply in
                            ReplyRowView(
                                reply: reply,
                                rootUri: threadRootUri,
                                rootCid: threadRootCid,
                                onReplyDismiss: {
                                    Task { await loadThread() }
                                }
                            )
                            .padding(.horizontal, Theme.lg)
                            .padding(.vertical, 10)

                            ThemedDivider()
                        }
                    }
                }
            }
        }
        .background(Theme.background)
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Snapshot engagement once — re-running on every appearance would
            // revert likes made in this view when returning from a push
            guard !didInitEngagement else { return }
            didInitEngagement = true
            isLiked = nav.viewerLike != nil
            likeUri = nav.viewerLike
            localLikeCount = nav.likeCount
            isReposted = nav.viewerRepost != nil
            repostUri = nav.viewerRepost
            localRepostCount = nav.repostCount
        }
        .task {
            if nav.isVerified {
                viewModel.verification.verify(postUri: nav.uri, postText: nav.text, authorDID: nav.authorDID)
            }
            await loadThread()
        }
        .refreshable {
            await loadThread()
        }
        .sheet(isPresented: $showReplySheet, onDismiss: {
            Task { await loadThread() }
        }) {
            ReplyView(
                replyToUri: nav.uri,
                replyToCid: nav.cid,
                replyToHandle: nav.authorHandle,
                replyToDisplayName: nav.authorDisplayName,
                replyToAvatar: nav.authorAvatar,
                replyToText: nav.text,
                rootUri: threadRootUri,
                rootCid: threadRootCid
            )
        }
        .sheet(isPresented: $showQuotePost) {
            QuotePostView(
                quotedUri: nav.uri,
                quotedCid: nav.cid,
                quotedHandle: nav.authorHandle,
                quotedDisplayName: nav.authorDisplayName,
                quotedAvatar: nav.authorAvatar,
                quotedText: nav.text
            )
        }
    }

    // MARK: - Main Post (Expanded)

    private var mainPostView: some View {
        VStack(alignment: .leading, spacing: Theme.md) {
            // Author row
            HStack(spacing: 10) {
                NavigationLink(value: nav.authorDID) {
                    AvatarView(url: nav.authorAvatar, handle: nav.authorHandle, size: .medium)
                }
                .buttonStyle(.plain)

                NavigationLink(value: nav.authorDID) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            if let name = nav.authorDisplayName, !name.isEmpty {
                                Text(name)
                                    .font(Theme.headline)
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            VerificationBadge(status: viewModel.verification.status(for: nav.uri))
                        }
                        Text("@\(nav.authorHandle)")
                            .font(Theme.subhead)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()
            }

            // Full post text — no line limit in detail view
            if !nav.text.isEmpty {
                Text(mentionHighlightedText(nav.text))
                    .font(Theme.body)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Post images / video
            if let images = nav.images, !images.isEmpty {
                PostImagesView(images: images)
            } else if let videoURL = nav.videoURL, let thumb = nav.videoThumbnail {
                PostVideoView(thumbnailURL: thumb, playlistURL: videoURL)
            }

            // Timestamp
            Text(fullDateString(from: nav.createdAt))
                .font(Theme.subhead)
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, Theme.xs)

            ThemedDivider()

            // Stats row
            HStack(spacing: Theme.lg) {
                if localRepostCount > 0 {
                    statLabel(count: localRepostCount, label: "Reposts")
                }
                if localLikeCount > 0 {
                    statLabel(count: localLikeCount, label: "Likes")
                }
                if nav.replyCount > 0 {
                    statLabel(count: nav.replyCount, label: "Replies")
                }
            }

            ThemedDivider()

            // Engagement buttons
            HStack(spacing: 0) {
                PostDetailButton(icon: "bubble.left", color: Theme.textTertiary) {
                    showReplySheet = true
                }
                .accessibilityIdentifier("reply-button")
                .accessibilityLabel("Reply")

                Spacer()

                PostDetailButton(
                    icon: "arrow.2.squarepath",
                    color: isReposted ? Theme.accent : Theme.textTertiary
                ) {
                    showRepostMenu = true
                }
                .accessibilityIdentifier("repost-button")
                .accessibilityLabel("Repost")
                .confirmationDialog("", isPresented: $showRepostMenu, titleVisibility: .hidden) {
                    Button(isReposted ? "Undo repost" : "Repost") {
                        Task { await toggleRepost() }
                    }
                    Button("Quote Post") {
                        showQuotePost = true
                    }
                    Button("Cancel", role: .cancel) {}
                }

                Spacer()

                PostDetailButton(
                    icon: isLiked ? "heart.fill" : "heart",
                    color: isLiked ? Theme.liked : Theme.textTertiary
                ) {
                    Task { await toggleLike() }
                }
                .accessibilityIdentifier("like-button")
                .accessibilityLabel("Like")

                Spacer()

                PostDetailButton(icon: "square.and.arrow.up", color: Theme.textTertiary) {
                    sharePost()
                }
                .accessibilityIdentifier("share-button")
                .accessibilityLabel("Share")
            }
        }
    }

    // MARK: - Reply Row (delegated to ReplyRowView for per-row state)

    // MARK: - Helpers

    private func statLabel(count: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(Theme.bodyEmphasis)
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(Theme.subhead)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func fullDateString(from isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: isoString) ?? ISO8601DateFormatter().date(from: isoString) else {
            return isoString
        }
        let display = DateFormatter()
        display.dateFormat = "h:mm a · MMM d, yyyy"
        return display.string(from: date)
    }

    // MARK: - Load Thread

    private func loadThread() async {
        isLoading = true
        do {
            let result = try await viewModel.atproto.getPostThread(uri: nav.uri)
            if let threadReplies = result.thread.replies {
                replies = threadReplies.compactMap { node -> ThreadReply? in
                    guard let post = node.post, let record = post.record else { return nil }
                    let rawText = record.text ?? ""
                    let tags = record.tags ?? []
                    let isSW = tags.contains("speakwrite") ||
                        rawText.contains("#speakwrite") ||
                        (rawText.contains("human verified") && rawText.contains("speakwrite"))
                    return ThreadReply(
                        uri: post.uri, cid: post.cid,
                        authorDID: post.author.did, authorHandle: post.author.handle,
                        authorDisplayName: post.author.displayName, authorAvatar: post.author.avatar,
                        text: ATProtoService.stripSpeakwriteFooter(rawText),
                        createdAt: record.createdAt ?? "",
                        likeCount: post.likeCount ?? 0, repostCount: post.repostCount ?? 0,
                        replyCount: post.replyCount ?? 0, viewer: post.viewer,
                        isSpeakwrite: isSW
                    )
                }
            }
        } catch {
            threadError = "Couldn't load replies. Check your connection."
        }
        isLoading = false
    }

    // MARK: - Engagement

    private func toggleLike() async {
        if isLiked, let uri = likeUri {
            isLiked = false; localLikeCount -= 1; likeUri = nil
            do {
                try await viewModel.atproto.unlikePost(likeUri: uri)
            } catch {
                isLiked = true; localLikeCount += 1; likeUri = uri
                print("[Speakwrite] Unlike failed: \(error)")
            }
        } else {
            isLiked = true; localLikeCount += 1
            do {
                likeUri = try await viewModel.atproto.likePost(uri: nav.uri, cid: nav.cid)
            } catch {
                isLiked = false; localLikeCount -= 1
                print("[Speakwrite] Like failed: \(error)")
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
                print("[Speakwrite] Unrepost failed: \(error)")
            }
        } else {
            isReposted = true; localRepostCount += 1
            do {
                repostUri = try await viewModel.atproto.repost(uri: nav.uri, cid: nav.cid)
            } catch {
                isReposted = false; localRepostCount -= 1
                print("[Speakwrite] Repost failed: \(error)")
            }
        }
    }

    private func sharePost() {
        let parts = nav.uri.components(separatedBy: "/")
        if let rkey = parts.last {
            let bskyURL = "https://bsky.app/profile/\(nav.authorHandle)/post/\(rkey)"
            let activityVC = UIActivityViewController(activityItems: [bskyURL], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
    }
}

// MARK: - Thread Reply Model

struct ThreadReply: Identifiable {
    let uri: String
    let cid: String
    let authorDID: String
    let authorHandle: String
    let authorDisplayName: String?
    let authorAvatar: String?
    let text: String
    let createdAt: String
    let likeCount: Int
    let repostCount: Int
    let replyCount: Int
    let viewer: PostViewer?
    let isSpeakwrite: Bool
    var id: String { uri }
}

// MARK: - Reply Row View (interactive)

private struct ReplyRowView: View {
    let reply: ThreadReply
    /// The thread root this reply belongs to (passed down from the detail view).
    let rootUri: String
    let rootCid: String
    var onReplyDismiss: (() -> Void)?
    @Environment(AppViewModel.self) private var viewModel

    @State private var isLiked = false
    @State private var likeUri: String?
    @State private var localLikeCount: Int = 0
    @State private var isReposted = false
    @State private var repostUri: String?
    @State private var localRepostCount: Int = 0
    @State private var showReplySheet = false
    @State private var showRepostMenu = false
    @State private var showQuotePost = false
    @State private var didInitEngagement = false

    /// Navigation value to open this reply's own sub-thread.
    private var replyNavigation: PostNavigation {
        PostNavigation(
            uri: reply.uri, cid: reply.cid,
            authorHandle: reply.authorHandle,
            authorDID: reply.authorDID,
            authorAvatar: reply.authorAvatar,
            authorDisplayName: reply.authorDisplayName,
            text: reply.text, createdAt: reply.createdAt,
            likeCount: localLikeCount, repostCount: localRepostCount,
            replyCount: reply.replyCount,
            viewerLike: likeUri, viewerRepost: repostUri,
            isVerified: reply.isSpeakwrite,
            images: nil, videoURL: nil, videoThumbnail: nil,
            rootUri: rootUri, rootCid: rootCid
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            NavigationLink(value: reply.authorDID) {
                AvatarView(url: reply.authorAvatar, handle: reply.authorHandle, size: .medium)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                // Header
                NavigationLink(value: reply.authorDID) {
                    HStack(spacing: 0) {
                        if let name = reply.authorDisplayName, !name.isEmpty {
                            Text(name)
                                .font(Theme.bodyEmphasis)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                                .layoutPriority(1)
                        }
                        if reply.isSpeakwrite {
                            Image(systemName: "checkmark.seal.fill")
                                .font(Theme.caption)
                                .foregroundStyle(Theme.accent)
                                .padding(.leading, 2)
                        }
                        Text(" @\(reply.authorHandle)")
                            .font(Theme.subhead)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(" · \(relativeTimeString(from: reply.createdAt))")
                            .font(Theme.subhead)
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .buttonStyle(.plain)

                // Reply text → opens this reply's own sub-thread
                if !reply.text.isEmpty {
                    NavigationLink(value: replyNavigation) {
                        Text(mentionHighlightedText(reply.text))
                            .font(Theme.body)
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .buttonStyle(.plain)
                }

                // Engagement row
                HStack(spacing: 0) {
                    replyButton
                    Spacer(minLength: 0)
                    repostButton
                    Spacer(minLength: 0)
                    likeButton
                    Spacer(minLength: 0)
                    shareButton
                }
                .frame(maxWidth: 280, alignment: .leading)
                .padding(.top, 2)
            }
        }
        .onAppear {
            guard !didInitEngagement else { return }
            didInitEngagement = true
            isLiked = reply.viewer?.like != nil
            likeUri = reply.viewer?.like
            localLikeCount = reply.likeCount
            isReposted = reply.viewer?.repost != nil
            repostUri = reply.viewer?.repost
            localRepostCount = reply.repostCount
        }
        .sheet(isPresented: $showReplySheet, onDismiss: {
            onReplyDismiss?()
        }) {
            ReplyView(
                replyToUri: reply.uri,
                replyToCid: reply.cid,
                replyToHandle: reply.authorHandle,
                replyToDisplayName: reply.authorDisplayName,
                replyToAvatar: reply.authorAvatar,
                replyToText: reply.text,
                rootUri: rootUri,
                rootCid: rootCid
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
                quotedUri: reply.uri,
                quotedCid: reply.cid,
                quotedHandle: reply.authorHandle,
                quotedDisplayName: reply.authorDisplayName,
                quotedAvatar: reply.authorAvatar,
                quotedText: reply.text
            )
        }
    }

    private var replyButton: some View {
        Button { showReplySheet = true } label: {
            HStack(spacing: 4) {
                Image(systemName: "bubble.left").font(Theme.body)
                if reply.replyCount > 0 {
                    Text(formatCount(reply.replyCount)).font(Theme.subhead)
                }
            }
            .foregroundStyle(Theme.textTertiary)
            .padding(5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reply")
    }

    private var repostButton: some View {
        Button { showRepostMenu = true } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.2.squarepath").font(Theme.body)
                if localRepostCount > 0 {
                    Text(formatCount(localRepostCount))
                        .font(Theme.subhead.weight(isReposted ? .semibold : .regular))
                }
            }
            .foregroundStyle(isReposted ? Theme.accent : Theme.textTertiary)
            .padding(5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Repost")
    }

    private var likeButton: some View {
        Button { Task { await toggleLike() } } label: {
            HStack(spacing: 4) {
                Image(systemName: isLiked ? "heart.fill" : "heart").font(Theme.body)
                if localLikeCount > 0 {
                    Text(formatCount(localLikeCount))
                        .font(Theme.subhead.weight(isLiked ? .semibold : .regular))
                }
            }
            .foregroundStyle(isLiked ? Theme.liked : Theme.textTertiary)
            .padding(5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Like")
    }

    private var shareButton: some View {
        Button { shareReply() } label: {
            Image(systemName: "square.and.arrow.up")
                .font(Theme.body)
                .foregroundStyle(Theme.textTertiary)
                .padding(5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Share")
    }

    private func toggleLike() async {
        if isLiked, let uri = likeUri {
            isLiked = false; localLikeCount -= 1; likeUri = nil
            do {
                try await viewModel.atproto.unlikePost(likeUri: uri)
            } catch {
                isLiked = true; localLikeCount += 1; likeUri = uri
            }
        } else {
            isLiked = true; localLikeCount += 1
            do {
                likeUri = try await viewModel.atproto.likePost(uri: reply.uri, cid: reply.cid)
            } catch {
                isLiked = false; localLikeCount -= 1
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
            }
        } else {
            isReposted = true; localRepostCount += 1
            do {
                repostUri = try await viewModel.atproto.repost(uri: reply.uri, cid: reply.cid)
            } catch {
                isReposted = false; localRepostCount -= 1
            }
        }
    }

    private func shareReply() {
        let parts = reply.uri.components(separatedBy: "/")
        if let rkey = parts.last {
            let bskyURL = "https://bsky.app/profile/\(reply.authorHandle)/post/\(rkey)"
            let activityVC = UIActivityViewController(activityItems: [bskyURL], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
    }
}

// MARK: - Detail Engagement Button

private struct PostDetailButton: View {
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 44, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        PostDetailView(nav: .preview)
    }
    .environment(AppViewModel.preview)
}
#endif
