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
            if viewModel.atproto.restoreSession() {
                Task { await viewModel.loadMyProfile() }
            }
        }
    }
}
