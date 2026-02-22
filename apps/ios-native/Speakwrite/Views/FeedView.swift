import SwiftUI

/// Global feed of human-verified posts with engagement actions.
struct VerifiedFeedView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showMyProfile = false
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
                        showMyProfile = true
                    }
                    Text("speakwrite")
                        .font(Theme.monoTitle)
                        .foregroundStyle(Theme.accent)
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.accent)
                        .font(.system(size: 14))
                    Spacer()
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
                                .foregroundStyle(Theme.textSecondary(colorScheme))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.verifiedPosts.isEmpty {
                        ContentUnavailableView {
                            Label("No verified posts yet", systemImage: "checkmark.seal")
                        } description: {
                            Text("Posts written with Speakwrite will appear here.\nBe the first to publish one.")
                                .font(Theme.mono)
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.verifiedPosts) { post in
                                    PostRow(post: post)
                                        .padding(.horizontal, Theme.lg)

                                    Divider()
                                        .foregroundStyle(Theme.separator(colorScheme))
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
            .background(Theme.background(colorScheme))
            .navigationBarHidden(true)
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
                if viewModel.verifiedPosts.isEmpty {
                    await viewModel.loadFeed()
                }
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
