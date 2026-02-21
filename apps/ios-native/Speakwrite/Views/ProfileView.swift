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
    @State private var loadError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Banner
                if let bannerURL = profile?.banner, let url = URL(string: bannerURL) {
                    Color.clear
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                        .background {
                            AsyncImage(url: url) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle().fill(Theme.surface(colorScheme))
                            }
                        }
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Theme.surface(colorScheme))
                        .frame(height: 150)
                }

                // Avatar + Follow button
                HStack {
                    AvatarView(url: profile?.avatar, handle: profile?.handle, size: .large)
                        .overlay(Circle().stroke(Theme.avatarBorder(colorScheme), lineWidth: 3))

                    Spacer()

                    if actorDID != viewModel.atproto.did {
                        Button {
                            Task {
                                if isFollowing, let uri = followUri {
                                    isFollowing = false; followUri = nil
                                    do {
                                        try await viewModel.atproto.unfollow(followUri: uri)
                                    } catch {
                                        isFollowing = true; followUri = uri
                                    }
                                } else {
                                    isFollowing = true
                                    do {
                                        try await viewModel.atproto.follow(did: actorDID)
                                    } catch {
                                        isFollowing = false
                                    }
                                }
                            }
                        } label: {
                            Text(isFollowing ? "Following" : "Follow")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(isFollowing ? Theme.textPrimary(colorScheme) : .white)
                                .padding(.horizontal, Theme.xl)
                                .padding(.vertical, Theme.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(isFollowing ? Theme.surface(colorScheme) : Theme.accent)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(isFollowing ? Theme.separator(colorScheme) : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.lg)
                .padding(.top, Theme.md)

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
                    ProgressView("Loading posts…")
                        .tint(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.xxxl)
                } else if let error = loadError {
                    VStack(spacing: Theme.sm) {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary(colorScheme))
                        Button("Retry") {
                            Task {
                                loadError = nil
                                await loadProfile()
                                await loadPosts()
                            }
                        }
                        .font(Theme.monoBold)
                        .foregroundStyle(Theme.accent)
                    }
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
                            PostRow(post: post, hideFollowButton: true)
                                .padding(.horizontal, Theme.lg)

                            Divider()
                                .foregroundStyle(Theme.separator(colorScheme))
                        }

                        if postsCursor != nil {
                            ProgressView("Loading more…")
                                .tint(Theme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.xl)
                                .onAppear { Task { await loadMorePosts() } }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("profile-view")
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
        .refreshable {
            loadError = nil
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
        } catch {
            loadError = "Couldn't load profile. Check your connection and try again."
        }
    }

    private func loadPosts() async {
        isLoading = true
        do {
            let result = try await viewModel.atproto.getAuthorFeed(actor: actorDID)
            posts = result.posts
            postsCursor = result.cursor
        } catch {
            if posts.isEmpty {
                loadError = "Couldn't load posts. Pull to refresh."
            }
        }
        isLoading = false
    }

    private func loadMorePosts() async {
        guard let cursor = postsCursor else { return }
        do {
            let result = try await viewModel.atproto.getAuthorFeed(actor: actorDID, cursor: cursor)
            posts.append(contentsOf: result.posts)
            postsCursor = result.cursor
        } catch {
            // Pagination failure is non-critical — user can scroll again
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ProfileView(actorDID: "did:plc:bob456")
    }
    .environment(AppViewModel.preview)
}
#endif
