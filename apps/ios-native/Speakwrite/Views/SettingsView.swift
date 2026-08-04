import SwiftUI

/// Settings screen — pushed from the Profile tab. Appearance toggle,
/// account info, and about section.
struct SettingsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @AppStorage("appearanceMode") private var appearanceMode: Int = AppearanceMode.system.rawValue
    @State private var showLogoutConfirm = false

    var body: some View {
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
                                .foregroundStyle(Theme.textPrimary)
                        }
                        Text("@\(viewModel.myProfile?.handle ?? viewModel.atproto.handle ?? "—")")
                            .font(Theme.mono)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.vertical, Theme.xs)
                .accessibilityIdentifier("account-info")
                .listRowBackground(Theme.surfaceElevated)
            }

            // Appearance
            Section("Appearance") {
                Picker("Theme", selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Theme.surfaceElevated)
            }

            // Account
            Section("Account") {
                if let handle = viewModel.atproto.handle {
                    LabeledContent("Handle") {
                        Text("@\(handle)")
                            .font(Theme.mono)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .listRowBackground(Theme.surfaceElevated)
                }

                if let did = viewModel.atproto.did {
                    LabeledContent("DID") {
                        Text(String(did.prefix(24)) + "...")
                            .font(Theme.monoSmall)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .listRowBackground(Theme.surfaceElevated)
                }

                Button(role: .destructive) {
                    showLogoutConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(Theme.body)
                        Text("Sign Out")
                            .font(Theme.monoBody)
                    }
                }
                .listRowBackground(Theme.surfaceElevated)
                .alert("Sign out?", isPresented: $showLogoutConfirm) {
                    Button("Sign Out", role: .destructive) {
                        viewModel.signOut()
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
                        .foregroundStyle(Theme.textSecondary)
                }
                .listRowBackground(Theme.surfaceElevated)

                HStack(spacing: Theme.sm) {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(Theme.accent)
                        .font(Theme.body)
                    Text("Built with hardware attestation")
                        .font(Theme.subhead)
                        .foregroundStyle(Theme.textSecondary)
                }
                .listRowBackground(Theme.surfaceElevated)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppViewModel.preview)
}
#endif
