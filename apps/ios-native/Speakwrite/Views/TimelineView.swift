import SwiftUI

/// Normal Bluesky timeline feed — shows all posts, with verified badge on Speakwrite posts.
struct TimelineView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showMyProfile = false

    var body: some View {
        NavigationStack {
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
                        Text("Your timeline is empty.")
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
                        viewModel.timelineCursor = nil
                        await viewModel.loadTimeline()
                    }
                }
            }
            .background(Theme.background(colorScheme))
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: Theme.sm) {
                        AvatarButton(
                            avatarURL: viewModel.myProfile?.avatar,
                            handle: viewModel.atproto.handle
                        ) {
                            showMyProfile = true
                        }
                        Text("Feed")
                            .font(Theme.monoTitle)
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showMyProfile) {
                MyProfileView()
            }
            .navigationDestination(for: String.self) { did in
                ProfileView(actorDID: did)
            }
            .navigationDestination(for: PostNavigation.self) { nav in
                PostDetailView(nav: nav)
            }
            .task {
                if viewModel.timelinePosts.isEmpty {
                    await viewModel.loadTimeline()
                }
            }
        }
    }
}
