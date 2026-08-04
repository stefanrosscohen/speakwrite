import SwiftUI

/// Shows another user's profile when tapping their avatar/name in a feed.
struct ProfileView: View {
    let actorDID: String
    @Environment(AppViewModel.self) private var viewModel
    @State private var profile: ProfileViewDetailed?
    @State private var posts: [TimelinePost] = []
    @State private var postsCursor: String?
    @State private var isLoading = true
    @State private var isFollowing = false
    @State private var isFollowWorking = false
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
                                Rectangle().fill(Theme.surface)
                            }
                        }
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Theme.surface)
                        .frame(height: 150)
                }

                // Avatar + Follow button
                HStack {
                    AvatarView(url: profile?.avatar, handle: profile?.handle, size: .large)
                        .overlay(Circle().stroke(Theme.background, lineWidth: 3))

                    Spacer()

                    if actorDID != viewModel.atproto.did {
                        FollowButton(isFollowing: isFollowing, isWorking: isFollowWorking) {
                            Task { await toggleFollow() }
                        }
                    }
                }
                .padding(.horizontal, Theme.lg)
                .padding(.top, Theme.md)

                // Name + handle
                VStack(alignment: .leading, spacing: 2) {
                    if let name = profile?.displayName, !name.isEmpty {
                        Text(name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Text("@\(profile?.handle ?? "")")
                        .font(Theme.body)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, Theme.lg)
                .padding(.top, Theme.sm)

                // Bio
                if let bio = profile?.description, !bio.isEmpty {
                    Text(bio)
                        .font(Theme.body)
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Theme.lg)
                        .padding(.top, Theme.sm)
                }

                // Stats row
                HStack(spacing: Theme.xl) {
                    ProfileStat(count: profile?.postsCount ?? 0, label: "posts")
                    ProfileStat(count: profile?.followersCount ?? 0, label: "followers")
                    ProfileStat(count: profile?.followsCount ?? 0, label: "following")
                }
                .padding(.horizontal, Theme.lg)
                .padding(.top, Theme.md)

                ThemedDivider()
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
                            .font(Theme.subhead)
                            .foregroundStyle(Theme.textSecondary)
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
                        .font(Theme.subhead)
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.xxxl)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(posts) { post in
                            PostRow(post: post, hideFollowButton: true)
                                .padding(.horizontal, Theme.lg)

                            ThemedDivider()
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
        .background(Theme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - Actions

    private func toggleFollow() async {
        isFollowWorking = true
        if isFollowing, let uri = followUri {
            do {
                try await viewModel.atproto.unfollow(followUri: uri)
                isFollowing = false
                followUri = nil
            } catch {
                // Keep current state on failure
            }
        } else {
            do {
                followUri = try await viewModel.atproto.follow(did: actorDID)
                isFollowing = true
            } catch {
                // Keep current state on failure
            }
        }
        isFollowWorking = false
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
