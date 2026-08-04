import SwiftUI

/// Feed tab with "Following" and "For You" sub-tabs.
struct TimelineView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var showSearch = false
    @State private var selectedFeed: FeedType = .following
    @State private var path = NavigationPath()

    enum FeedType: String, CaseIterable {
        case following = "Following"
        case forYou = "For You"
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                // App header
                HStack(spacing: Theme.sm) {
                    AvatarButton(
                        avatarURL: viewModel.myProfile?.avatar,
                        handle: viewModel.atproto.handle
                    ) {
                        viewModel.selectedTab = .profile
                    }
                    Text("speakwrite")
                        .font(Theme.monoTitle)
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Theme.accent)
                    }
                    .accessibilityLabel("Search")
                }
                .padding(.horizontal, Theme.lg)
                .padding(.vertical, Theme.sm)

                // Sub-tab picker
                feedPicker

                ThemedDivider()

                // Feed content
                Group {
                    switch selectedFeed {
                    case .following:
                        followingFeedContent
                    case .forYou:
                        forYouFeedContent
                    }
                }
            }
            .background(Theme.background)
            .navigationBarHidden(true)
            .sheet(isPresented: $showSearch) {
                SearchUsersView()
            }
            .navigationDestination(for: String.self) { did in
                ProfileView(actorDID: did)
            }
            .navigationDestination(for: PostNavigation.self) { nav in
                PostDetailView(nav: nav)
            }
            .task {
                await viewModel.loadFollowing()
                await viewModel.loadTimeline()
            }
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "speakwrite", url.host == "profile",
                   let handle = url.pathComponents.dropFirst().first {
                    path.append(handle)
                    return .handled
                }
                return .systemAction
            })
        }
    }

    // MARK: - Feed Picker

    private var feedPicker: some View {
        HStack(spacing: 0) {
            ForEach(FeedType.allCases, id: \.self) { feed in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFeed = feed
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(feed.rawValue)
                            .font(Theme.mono.weight(selectedFeed == feed ? .semibold : .regular))
                            .foregroundStyle(selectedFeed == feed ? Theme.textPrimary : Theme.textSecondary)

                        Rectangle()
                            .fill(selectedFeed == feed ? Theme.accent : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(feed == .following ? "following-tab" : "for-you-tab")
            }
        }
        .padding(.horizontal, Theme.lg)
    }

    // MARK: - Following Feed

    private var followingFeedContent: some View {
        Group {
            if viewModel.isFollowingLoading && viewModel.followingPosts.isEmpty {
                VStack(spacing: Theme.md) {
                    ProgressView()
                        .tint(Theme.accent)
                    Text("Loading feed...")
                        .font(Theme.mono)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.followingError, viewModel.followingPosts.isEmpty {
                ErrorStateView(message: error) {
                    Task { await viewModel.loadFollowing() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.followingPosts.isEmpty {
                EmptyStateView(
                    icon: "person.2",
                    title: "No posts",
                    subtitle: "Follow people to see their posts here."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.followingPosts) { post in
                            PostRow(post: post)
                                .padding(.horizontal, Theme.lg)

                            ThemedDivider()
                        }

                        if viewModel.followingCursor != nil {
                            ProgressView()
                                .tint(Theme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.xl)
                                .onAppear {
                                    Task { await viewModel.loadMoreFollowing() }
                                }
                        }
                    }
                }
                .refreshable {
                    await viewModel.loadFollowing()
                }
            }
        }
    }

    // MARK: - For You Feed

    private var forYouFeedContent: some View {
        Group {
            if viewModel.isTimelineLoading && viewModel.timelinePosts.isEmpty {
                VStack(spacing: Theme.md) {
                    ProgressView()
                        .tint(Theme.accent)
                    Text("Loading feed...")
                        .font(Theme.mono)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.timelineError, viewModel.timelinePosts.isEmpty {
                ErrorStateView(message: error) {
                    Task { await viewModel.loadTimeline() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.timelinePosts.isEmpty {
                EmptyStateView(
                    icon: "house",
                    title: "No posts",
                    subtitle: "Your feed is empty."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.timelinePosts) { post in
                            PostRow(post: post)
                                .padding(.horizontal, Theme.lg)

                            ThemedDivider()
                        }

                        if viewModel.timelineCursor != nil {
                            ProgressView()
                                .tint(Theme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.xl)
                                .onAppear {
                                    Task { await viewModel.loadMoreTimeline() }
                                }
                        }
                    }
                }
                .refreshable {
                    await viewModel.loadTimeline()
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    TimelineView()
        .environment(AppViewModel.preview)
}
#endif
