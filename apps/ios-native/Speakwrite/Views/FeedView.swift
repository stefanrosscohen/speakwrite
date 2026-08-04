import SwiftUI

/// Global feed of human-verified posts with engagement actions.
struct VerifiedFeedView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var showSearch = false
    @State private var path = NavigationPath()

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
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.accent)
                        .font(Theme.subhead)
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

                // Feed content
                Group {
                    if viewModel.isFeedLoading && viewModel.verifiedPosts.isEmpty {
                        VStack(spacing: Theme.md) {
                            ProgressView()
                                .tint(Theme.accent)
                            Text("Loading verified posts...")
                                .font(Theme.mono)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = viewModel.feedError, viewModel.verifiedPosts.isEmpty {
                        ErrorStateView(message: error) {
                            Task { await viewModel.loadFeed() }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.verifiedPosts.isEmpty {
                        EmptyStateView(
                            icon: "checkmark.seal",
                            title: "No verified posts yet",
                            subtitle: "Posts written with Speakwrite will appear here.\nBe the first to publish one."
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.verifiedPosts) { post in
                                    PostRow(post: post)
                                        .padding(.horizontal, Theme.lg)

                                    ThemedDivider()
                                }

                                if viewModel.feedCursor != nil {
                                    ProgressView()
                                        .tint(Theme.accent)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, Theme.xl)
                                        .onAppear {
                                            Task { await viewModel.loadMoreFeed() }
                                        }
                                }
                            }
                        }
                        .accessibilityIdentifier("verified-feed")
                        .refreshable {
                            await viewModel.loadFeed()
                        }
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
                await viewModel.loadFeed()
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
}

#if DEBUG
#Preview("With Posts") {
    VerifiedFeedView()
        .environment(AppViewModel.preview)
}

#Preview("Empty") {
    VerifiedFeedView()
        .environment(AppViewModel.previewEmpty)
}
#endif
