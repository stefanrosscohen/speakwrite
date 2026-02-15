import SwiftUI

/// Shows another user's profile when tapping their avatar/name in a feed.
struct ProfileView: View {
    let actorDID: String
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var profile: ProfileViewDetailed?
    @State private var posts: [TimelinePost] = []
    @State private var postsCursor: String?
    @State private var isLoading = true
    @State private var isFollowing = false
    @State private var followUri: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Banner
                if let bannerURL = profile?.banner, let url = URL(string: bannerURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Theme.surface(colorScheme))
                    }
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(Theme.surface(colorScheme))
                        .frame(height: 150)
                }

                // Avatar + Follow button row
                HStack(alignment: .bottom) {
                    AvatarView(url: profile?.avatar, handle: profile?.handle, size: .large)
                        .overlay(Circle().stroke(Theme.avatarBorder(colorScheme), lineWidth: 3))
                        .offset(y: -35)

                    Spacer()

                    if actorDID != viewModel.atproto.did {
                        Button {
                            Task {
                                if isFollowing, let uri = followUri {
                                    try? await viewModel.atproto.unfollow(followUri: uri)
                                    isFollowing = false
                                    followUri = nil
                                } else {
                                    try? await viewModel.atproto.follow(did: actorDID)
                                    isFollowing = true
                                }
                            }
                        } label: {
                            Text(isFollowing ? "Following" : "Follow")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, Theme.xl)
                                .padding(.vertical, Theme.sm)
                        }
                        .buttonStyle(.bordered)
                        .tint(isFollowing ? Theme.textSecondary(colorScheme) : Theme.accent)
                    }
                }
                .padding(.horizontal, Theme.lg)
                .padding(.bottom, -30)

                // Name + handle
                VStack(alignment: .leading, spacing: 2) {
                    if let name = profile?.displayName, !name.isEmpty {
                        Text(name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.textPrimary(colorScheme))
                    }
                    Text("@\(profile?.handle ?? "")")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary(colorScheme))
                }
                .padding(.horizontal, Theme.lg)
                .padding(.top, Theme.sm)

                // Bio
                if let bio = profile?.description, !bio.isEmpty {
                    Text(bio)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textPrimary(colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Theme.lg)
                        .padding(.top, Theme.sm)
                }

                // Stats row
                HStack(spacing: Theme.xl) {
                    profileStat(count: profile?.postsCount ?? 0, label: "Posts")
                    profileStat(count: profile?.followersCount ?? 0, label: "Followers")
                    profileStat(count: profile?.followsCount ?? 0, label: "Following")
                }
                .padding(.horizontal, Theme.lg)
                .padding(.top, Theme.md)

                Divider()
                    .foregroundStyle(Theme.separator(colorScheme))
                    .padding(.top, Theme.lg)

                // Author's posts
                if isLoading {
                    ProgressView()
                        .tint(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.xxxl)
                } else if posts.isEmpty {
                    Text("No posts yet")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textTertiary(colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.xxxl)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(posts) { post in
                            PostRow(post: post)
                                .padding(.horizontal, Theme.lg)

                            Divider()
                                .foregroundStyle(Theme.separator(colorScheme))
                        }

                        if postsCursor != nil {
                            ProgressView()
                                .tint(Theme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.xl)
                                .onAppear { Task { await loadMorePosts() } }
                        }
                    }
                }
            }
        }
        .background(Theme.background(colorScheme))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: String.self) { did in
            ProfileView(actorDID: did)
        }
        .navigationDestination(for: PostNavigation.self) { nav in
            PostDetailView(nav: nav)
        }
        .task {
            await loadProfile()
            await loadPosts()
        }
    }

    // MARK: - Helpers

    private func profileStat(count: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Text(formatStatCount(count))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary(colorScheme))
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary(colorScheme))
        }
    }

    private func formatStatCount(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }

    // MARK: - Data Loading

    private func loadProfile() async {
        do {
            profile = try await viewModel.atproto.getProfile(actor: actorDID)
            isFollowing = profile?.viewer?.following != nil
            followUri = profile?.viewer?.following
        } catch {}
    }

    private func loadPosts() async {
        isLoading = true
        do {
            let result = try await viewModel.atproto.getAuthorFeed(actor: actorDID)
            posts = result.posts
            postsCursor = result.cursor
        } catch {}
        isLoading = false
    }

    private func loadMorePosts() async {
        guard let cursor = postsCursor else { return }
        do {
            let result = try await viewModel.atproto.getAuthorFeed(actor: actorDID, cursor: cursor)
            posts.append(contentsOf: result.posts)
            postsCursor = result.cursor
        } catch {}
    }
}
