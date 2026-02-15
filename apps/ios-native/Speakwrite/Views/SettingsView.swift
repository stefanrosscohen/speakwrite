import SwiftUI

/// Settings tab with appearance toggle, account info, and about section.
struct SettingsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appearanceMode") private var appearanceMode: Int = AppearanceMode.system.rawValue

    var body: some View {
        NavigationStack {
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
                        viewModel.atproto.logout()
                        viewModel.myProfile = nil
                        viewModel.verifiedPosts = []
                        viewModel.timelinePosts = []
                        viewModel.feedCursor = nil
                        viewModel.timelineCursor = nil
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 15))
                            Text("Sign Out")
                                .font(Theme.monoBody)
                        }
                    }
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
            .background(Theme.background(colorScheme))
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Settings")
                        .font(Theme.monoTitle)
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }
}
