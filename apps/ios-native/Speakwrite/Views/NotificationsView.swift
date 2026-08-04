import SwiftUI

/// Activity tab — likes, reposts, follows, replies, mentions, and quotes.
struct NotificationsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                TabHeader("Activity")

                ThemedDivider()

                content
            }
            .background(Theme.background)
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { did in
                ProfileView(actorDID: did)
            }
            .navigationDestination(for: PostNavigation.self) { nav in
                PostDetailView(nav: nav)
            }
            .task {
                await viewModel.loadNotifications()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isNotificationsLoading && viewModel.notifications.isEmpty {
            VStack(spacing: Theme.md) {
                ProgressView()
                    .tint(Theme.accent)
                Text("Loading activity...")
                    .font(Theme.mono)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.notificationsError, viewModel.notifications.isEmpty {
            ErrorStateView(message: error) {
                Task { await viewModel.loadNotifications() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.notifications.isEmpty {
            EmptyStateView(
                icon: "bell",
                title: "Nothing yet",
                subtitle: "Likes, reposts, follows, and replies to your posts will show up here."
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.notifications) { notification in
                        NotificationRow(notification: notification)
                            .padding(.horizontal, Theme.lg)

                        ThemedDivider()
                    }

                    if viewModel.notificationsCursor != nil {
                        ProgressView()
                            .tint(Theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.xl)
                            .onAppear {
                                Task { await viewModel.loadMoreNotifications() }
                            }
                    }
                }
            }
            .accessibilityIdentifier("notifications-list")
            .refreshable {
                await viewModel.loadNotifications()
            }
        }
    }
}

// MARK: - Notification Row

struct NotificationRow: View {
    let notification: AppNotification
    @Environment(AppViewModel.self) private var viewModel

    private var authorName: String {
        if let name = notification.author.displayName, !name.isEmpty {
            return name
        }
        return "@\(notification.author.handle)"
    }

    private var reasonIcon: (name: String, color: Color) {
        switch notification.reason {
        case "like": return ("heart.fill", Theme.liked)
        case "repost": return ("arrow.2.squarepath", Theme.accent)
        case "follow": return ("person.fill.badge.plus", Theme.accent)
        case "reply": return ("arrowshape.turn.up.left.fill", Theme.textSecondary)
        case "mention": return ("at", Theme.accent)
        case "quote": return ("quote.opening", Theme.textSecondary)
        default: return ("bell.fill", Theme.textSecondary)
        }
    }

    private var reasonText: String {
        switch notification.reason {
        case "like": return "liked your post"
        case "repost": return "reposted your post"
        case "follow": return "followed you"
        case "reply": return "replied to your post"
        case "mention": return "mentioned you"
        case "quote": return "quoted your post"
        default: return "interacted with you"
        }
    }

    /// The snippet shown under the header: the notification's own text for
    /// replies/mentions/quotes, or the subject post's text for likes/reposts.
    private var snippet: String? {
        if let text = notification.recordText, !text.isEmpty {
            return ATProtoService.stripSpeakwriteFooter(text)
        }
        if let subjectUri = notification.reasonSubject,
           let subject = viewModel.notificationSubjects[subjectUri],
           let text = subject.record?.text, !text.isEmpty {
            return ATProtoService.stripSpeakwriteFooter(text)
        }
        return nil
    }

    /// Where tapping the row goes: the relevant post when we have it, the
    /// author's profile for follows.
    private var destinationPost: PostNavigation? {
        // Replies/mentions/quotes: open the notification's own post
        if ["reply", "mention", "quote"].contains(notification.reason),
           let post = viewModel.notificationSubjects[notification.uri] {
            return post.asPostNavigation
        }
        // Likes/reposts: open the post that was liked/reposted
        if let subjectUri = notification.reasonSubject,
           let post = viewModel.notificationSubjects[subjectUri] {
            return post.asPostNavigation
        }
        return nil
    }

    var body: some View {
        Group {
            if let nav = destinationPost {
                NavigationLink(value: nav) { rowContent }
            } else {
                NavigationLink(value: notification.author.did) { rowContent }
            }
        }
        .buttonStyle(.plain)
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: Theme.md) {
            Image(systemName: reasonIcon.name)
                .font(Theme.body)
                .foregroundStyle(reasonIcon.color)
                .frame(width: 24, alignment: .center)
                .padding(.top, 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Theme.xs) {
                HStack(spacing: Theme.sm) {
                    AvatarView(url: notification.author.avatar, handle: notification.author.handle, size: .small)

                    // Author + reason, wrapping as one line of text
                    (Text(authorName).font(Theme.bodyEmphasis).foregroundStyle(Theme.textPrimary)
                        + Text(" \(reasonText)").font(Theme.body).foregroundStyle(Theme.textSecondary))
                        .lineLimit(2)

                    Spacer(minLength: Theme.xs)

                    Text(relativeTimeString(from: notification.indexedAt))
                        .font(Theme.subhead)
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: true, vertical: false)
                }

                if let snippet {
                    Text(snippet)
                        .font(Theme.subhead)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                        .padding(.leading, Theme.avatarSmall + Theme.sm)
                }
            }
        }
        .padding(.vertical, Theme.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            notification.isRead
                ? Color.clear
                : Theme.accentSubtle.opacity(0.4)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(authorName) \(reasonText)")
    }
}

// MARK: - FeedPost → PostNavigation

extension FeedPost {
    /// Build a navigation value for opening this post in the detail view.
    var asPostNavigation: PostNavigation {
        let images = embed?.images ?? embed?.media?.images
        return PostNavigation(
            uri: uri,
            cid: cid,
            authorHandle: author.handle,
            authorDID: author.did,
            authorAvatar: author.avatar,
            authorDisplayName: author.displayName,
            text: ATProtoService.stripSpeakwriteFooter(record?.text ?? ""),
            createdAt: record?.createdAt ?? "",
            likeCount: likeCount ?? 0,
            repostCount: repostCount ?? 0,
            replyCount: replyCount ?? 0,
            viewerLike: viewer?.like,
            viewerRepost: viewer?.repost,
            isVerified: record?.isSpeakwrite == true,
            images: images,
            videoURL: embed?.playlist ?? embed?.media?.playlist,
            videoThumbnail: embed?.thumbnail ?? embed?.media?.thumbnail,
            rootUri: record?.reply?.root?.uri,
            rootCid: record?.reply?.root?.cid
        )
    }
}

#if DEBUG
#Preview {
    NotificationsView()
        .environment(AppViewModel.preview)
}
#endif
