import SwiftUI

/// Settings tab with appearance toggle, account info, and about section.
struct SettingsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appearanceMode") private var appearanceMode: Int = AppearanceMode.system.rawValue
    @State private var showLogoutConfirm = false
    @State private var showMyProfile = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppHeader(onAvatarTap: { showMyProfile = true })

                List {
                    // Profile header
                    Section {
                        HStack(spacing: Theme.md) {
                            AvatarView(
                                url: viewModel.myProfile?.avatar,
                                handle: viewModel.atproto.handle,
                                size: .medium
                            )

                            VStack(alignment: .leading, spacing: Theme.xs) {
                                if let name = viewModel.myProfile?.displayName, !name.isEmpty {
                                    Text(name)
                                        .font(Theme.headline)
                                        .foregroundStyle(Theme.textPrimary(colorScheme))
                                }
                                Text("@\(viewModel.myProfile?.handle ?? viewModel.atproto.handle ?? "—")")
                                    .font(Theme.mono)
                                    .foregroundStyle(Theme.textSecondary(colorScheme))
                            }
                        }
                        .padding(.vertical, Theme.xs)
                        .accessibilityIdentifier("account-info")
                        .listRowBackground(Theme.surfaceElevated(colorScheme))
                    }

                    // Appearance
                    Section("Appearance") {
                        Picker("Theme", selection: $appearanceMode) {
                            ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                                Text(mode.label).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Theme.surfaceElevated(colorScheme))
                    }

                    // Verification
                    Section("Verification") {
                        HStack(spacing: Theme.sm) {
                            Image(systemName: "lock.shield")
                                .foregroundStyle(Theme.accent)
                                .font(.system(size: 15))
                            Text("Posts are signed by this device's Secure Enclave and verified by readers on their own devices — no server in the loop.")
                                .font(Theme.subhead)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .listRowBackground(Theme.elevatedColor)

                        Link(destination: URL(string: "https://www.speakwrite.io/verify")!) {
                            LabeledContent("Web verifier") {
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                        }
                        .listRowBackground(Theme.elevatedColor)

                        Link(destination: URL(string: "https://bsky.app/profile/verify.speakwrite.io")!) {
                            LabeledContent("Verification bot") {
                                HStack(spacing: 4) {
                                    Text("@verify.speakwrite.io")
                                        .font(Theme.monoSmall)
                                        .foregroundStyle(Theme.secondaryText)
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.tertiaryText)
                                }
                            }
                        }
                        .listRowBackground(Theme.elevatedColor)
                    }

                    // Account
                    Section("Account") {
                        if let pdsHost = viewModel.atproto.pdsHost {
                            LabeledContent("Data server") {
                                HStack(spacing: 4) {
                                    if viewModel.atproto.pdsUnreachable {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Theme.warning)
                                    }
                                    Text(pdsHost)
                                        .font(Theme.mono)
                                        .foregroundStyle(viewModel.atproto.pdsUnreachable ? Theme.warning : Theme.secondaryText)
                                }
                            }
                            .listRowBackground(Theme.elevatedColor)
                        }

                        if let handle = viewModel.atproto.handle {
                            LabeledContent("Handle") {
                                Text("@\(handle)")
                                    .font(Theme.mono)
                                    .foregroundStyle(Theme.textSecondary(colorScheme))
                            }
                            .listRowBackground(Theme.surfaceElevated(colorScheme))
                        }

                        if let did = viewModel.atproto.did {
                            LabeledContent("DID") {
                                Text(String(did.prefix(24)) + "...")
                                    .font(Theme.monoSmall)
                                    .foregroundStyle(Theme.textTertiary(colorScheme))
                            }
                            .listRowBackground(Theme.surfaceElevated(colorScheme))
                        }

                        Button(role: .destructive) {
                            showLogoutConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 15))
                                Text("Sign Out")
                                    .font(Theme.monoBody)
                            }
                        }
                        .listRowBackground(Theme.surfaceElevated(colorScheme))
                        .alert("Sign out?", isPresented: $showLogoutConfirm) {
                            Button("Sign Out", role: .destructive) {
                                viewModel.atproto.logout()
                                viewModel.myProfile = nil
                                viewModel.verifiedPosts = []
                                viewModel.timelinePosts = []
                                viewModel.followingPosts = []
                                viewModel.feedCursor = nil
                                viewModel.timelineCursor = nil
                                viewModel.followingCursor = nil
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("You'll need to sign in again to post or view your verified feed.")
                        }
                    }

                    // About
                    Section("About") {
                        LabeledContent("Version") {
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                .font(Theme.mono)
                                .foregroundStyle(Theme.textSecondary(colorScheme))
                        }
                        .listRowBackground(Theme.surfaceElevated(colorScheme))

                        Link(destination: URL(string: "https://www.speakwrite.io")!) {
                            LabeledContent("Website") {
                                HStack(spacing: 4) {
                                    Text("speakwrite.io")
                                        .font(Theme.mono)
                                        .foregroundStyle(Theme.secondaryText)
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.tertiaryText)
                                }
                            }
                        }
                        .listRowBackground(Theme.surfaceElevated(colorScheme))
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .background(Theme.background(colorScheme))
            .navigationBarHidden(true)
            .sheet(isPresented: $showMyProfile) {
                MyProfileView()
            }
        }
    }
}

#if DEBUG
#Preview {
    SettingsView()
        .environment(AppViewModel.preview)
}
#endif
