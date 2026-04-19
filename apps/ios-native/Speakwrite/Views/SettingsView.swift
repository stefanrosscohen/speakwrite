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
                    Spacer()
                }
                .padding(.horizontal, Theme.lg)
                .padding(.vertical, Theme.sm)

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

                    // Account
                    Section("Account") {
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

                    // World ID Verification
                    Section("Identity") {
                        WorldIDVerifyRow()
                            .listRowBackground(Theme.surfaceElevated(colorScheme))
                    }

                    // About
                    Section("About") {
                        LabeledContent("Version") {
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                .font(Theme.mono)
                                .foregroundStyle(Theme.textSecondary(colorScheme))
                        }
                        .listRowBackground(Theme.surfaceElevated(colorScheme))

                        HStack(spacing: Theme.sm) {
                            Image(systemName: "lock.shield")
                                .foregroundStyle(Theme.accent)
                                .font(.system(size: 15))
                            Text("Built with hardware attestation")
                                .font(Theme.subhead)
                                .foregroundStyle(Theme.textSecondary(colorScheme))
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
