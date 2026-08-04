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

    var body: some View {
        Group {
            if viewModel.atproto.isLoggedIn {
                @Bindable var vm = viewModel
                TabView(selection: $vm.selectedTab) {
                    TimelineView()
                        .tabItem {
                            Label("Feed", systemImage: "house")
                        }
                        .tag(AppViewModel.AppTab.timeline)

                    VerifiedFeedView()
                        .tabItem {
                            Label("Verified", systemImage: "checkmark.seal")
                        }
                        .tag(AppViewModel.AppTab.verified)

                    EditorView()
                        .tabItem {
                            Label("Compose", systemImage: "square.and.pencil")
                        }
                        .tag(AppViewModel.AppTab.compose)

                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .tag(AppViewModel.AppTab.settings)
                }
                .tint(Theme.accent)
                .onChange(of: viewModel.selectedTab) { _, newTab in
                    if newTab == .verified {
                        Task { await viewModel.loadFeed() }
                    }
                    if newTab == .timeline {
                        Task { await viewModel.loadFollowing() }
                    }
                }
            } else {
                LoginView()
            }
        }
        .onAppear {
            viewModel.atproto.restoreSession()
        }
        .onChange(of: viewModel.atproto.isLoggedIn) { _, isLoggedIn in
            // Fires for both restored sessions and fresh sign-ins, so the
            // profile (avatar, display name) and feeds load in either path.
            guard isLoggedIn else { return }
            Task {
                async let profile: () = viewModel.loadMyProfile()
                async let feeds: () = viewModel.loadAllFeeds()
                _ = await (profile, feeds)
            }
        }
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
