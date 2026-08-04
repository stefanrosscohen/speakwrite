import SwiftUI

@main
struct SpeakwriteApp: App {
    @State private var viewModel = AppViewModel()
    @AppStorage("appearanceMode") private var appearanceMode: Int = AppearanceMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
        }
    }
}

struct ContentView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if viewModel.atproto.isLoggedIn {
                loggedInBody
            } else {
                LoginView()
            }
        }
        .onAppear {
            if viewModel.atproto.restoreSession() {
                Task {
                    async let profile: () = viewModel.loadMyProfile()
                    async let feeds: () = viewModel.loadAllFeeds()
                    async let unread: () = viewModel.refreshUnreadCount()
                    _ = await (profile, feeds, unread)
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, viewModel.atproto.isLoggedIn {
                Task { await viewModel.refreshUnreadCount() }
            }
        }
    }

    private var loggedInBody: some View {
        @Bindable var vm = viewModel
        return ZStack(alignment: .bottomTrailing) {
            TabView(selection: $vm.selectedTab) {
                TimelineView()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                    .tag(AppViewModel.AppTab.timeline)

                VerifiedFeedView()
                    .tabItem {
                        Label("Verified", systemImage: "checkmark.seal")
                    }
                    .tag(AppViewModel.AppTab.verified)

                NotificationsView()
                    .tabItem {
                        Label("Activity", systemImage: "bell")
                    }
                    .badge(viewModel.unreadNotificationCount > 0 ? viewModel.unreadNotificationCount : 0)
                    .tag(AppViewModel.AppTab.notifications)

                MyProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.crop.circle")
                    }
                    .tag(AppViewModel.AppTab.profile)
            }
            .tint(Theme.accent)
            .onChange(of: viewModel.selectedTab) { _, newTab in
                switch newTab {
                case .verified:
                    Task { await viewModel.loadFeed() }
                case .timeline:
                    Task { await viewModel.loadFollowing() }
                case .notifications, .profile:
                    break
                }
            }

            ComposeFAB()
        }
        .fullScreenCover(isPresented: $vm.showCompose) {
            EditorView()
        }
    }
}

/// Floating compose button — the one entry point to writing, available from
/// every tab.
private struct ComposeFAB: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        Button {
            viewModel.showCompose = true
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Theme.accent))
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Compose post")
        .accessibilityIdentifier("compose_fab")
        .padding(.trailing, Theme.xl)
        .padding(.bottom, 64)
    }
}

#if DEBUG
#Preview("Logged In") {
    ContentView()
        .environment(AppViewModel.preview)
}

#Preview("Logged Out") {
    ContentView()
        .environment(AppViewModel.previewLoggedOut)
}
#endif
