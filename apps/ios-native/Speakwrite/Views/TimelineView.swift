import SwiftUI

/// Feed tab with "Following" and "For You" sub-tabs.
struct TimelineView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showMyProfile = false
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
                AppHeader(onAvatarTap: { showMyProfile = true }) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Theme.accent)
                    }
                    .accessibilityIdentifier("search-button")
                }

                if viewModel.atproto.pdsUnreachable {
                    PDSStatusBanner()
                }

                // Sub-tab picker
                feedPicker

                Divider()
                    .foregroundStyle(Theme.separator(colorScheme))

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
            .background(Theme.background(colorScheme))
            .navigationBarHidden(true)
            .sheet(isPresented: $showMyProfile) {
                MyProfileView()
            }
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
                            .font(.system(size: 14, weight: selectedFeed == feed ? .semibold : .regular, design: .monospaced))
                            .foregroundStyle(selectedFeed == feed ? Theme.textPrimary(colorScheme) : Theme.textSecondary(colorScheme))

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
                        .foregroundStyle(Theme.textSecondary(colorScheme))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.followingPosts.isEmpty {
                ContentUnavailableView {
                    Label("No posts", systemImage: "person.2")
                } description: {
                    Text("Follow people to see their posts here.")
                        .font(Theme.mono)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.followingPosts) { post in
                            PostRow(post: post)
                                .padding(.horizontal, Theme.lg)

                            Divider()
                                .foregroundStyle(Theme.separator(colorScheme))
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
                        .foregroundStyle(Theme.textSecondary(colorScheme))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.timelinePosts.isEmpty {
                ContentUnavailableView {
                    Label("No posts", systemImage: "house")
                } description: {
                    Text("Your feed is empty.")
                        .font(Theme.mono)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.timelinePosts) { post in
                            PostRow(post: post)
                                .padding(.horizontal, Theme.lg)

                            Divider()
                                .foregroundStyle(Theme.separator(colorScheme))
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
