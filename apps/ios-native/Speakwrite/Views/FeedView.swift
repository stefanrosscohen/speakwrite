import SwiftUI

/// Global feed of human-verified posts with engagement actions.
struct VerifiedFeedView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showMyProfile = false
    @State private var path = NavigationPath()
    @State private var showPublishToast = false

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                AppHeader(showSeal: true, onAvatarTap: { showMyProfile = true })

                if let message = viewModel.feedErrorMessage {
                    FeedStatusBanner(message: message) {
                        Task { await viewModel.loadFeed() }
                    }
                    Divider()
                        .foregroundStyle(Theme.separator(colorScheme))
                }

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
            .overlay(alignment: .top) {
                // Publish confirmation — the one moment the product pays off.
                if showPublishToast {
                    SuccessToast(message: "Published & sealed")
                        .padding(.top, Theme.sm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onChange(of: viewModel.publishSuccessAt) { _, newValue in
                guard newValue != nil else { return }
                withAnimation(.spring(duration: 0.35)) { showPublishToast = true }
                Task {
                    try? await Task.sleep(for: .seconds(2.5))
                    withAnimation(.easeOut(duration: 0.25)) { showPublishToast = false }
                    viewModel.publishSuccessAt = nil
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
                await viewModel.loadFeed()
                // Handle the publish → tab-switch case where the toast trigger
                // fires before this view is on screen.
                if let publishedAt = viewModel.publishSuccessAt,
                   Date().timeIntervalSince(publishedAt) < 5 {
                    withAnimation(.spring(duration: 0.35)) { showPublishToast = true }
                    try? await Task.sleep(for: .seconds(2.5))
                    withAnimation(.easeOut(duration: 0.25)) { showPublishToast = false }
                    viewModel.publishSuccessAt = nil
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
