import SwiftUI

/// User search screen — search bar with debounced input, results list with profiles.
struct SearchUsersView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [ProfileViewBasic] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: Theme.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.textSecondary(colorScheme))

                    TextField("Search users...", text: $query)
                        .font(.system(size: 16, design: .monospaced))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("search-field")

                    if !query.isEmpty {
                        Button {
                            query = ""
                            results = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Theme.textTertiary(colorScheme))
                        }
                    }
                }
                .padding(.horizontal, Theme.lg)
                .padding(.vertical, Theme.sm)
                .background(Theme.surfaceElevated(colorScheme))

                Divider()
                    .foregroundStyle(Theme.separator(colorScheme))

                // Results
                if isSearching && results.isEmpty {
                    VStack(spacing: Theme.md) {
                        ProgressView()
                            .tint(Theme.accent)
                        Text("Searching...")
                            .font(Theme.mono)
                            .foregroundStyle(Theme.textSecondary(colorScheme))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty && !query.isEmpty {
                    ContentUnavailableView {
                        Label("No results", systemImage: "person.slash")
                    } description: {
                        Text("No users found for \"\(query)\"")
                            .font(Theme.mono)
                    }
                } else if results.isEmpty {
                    ContentUnavailableView {
                        Label("Search", systemImage: "magnifyingglass")
                    } description: {
                        Text("Search for users by name or handle.")
                            .font(Theme.mono)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(results) { profile in
                                NavigationLink(value: profile.did) {
                                    SearchResultRow(profile: profile)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("search-result")

                                Divider()
                                    .foregroundStyle(Theme.separator(colorScheme))
                            }
                        }
                    }
                }
            }
            .background(Theme.background(colorScheme))
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: String.self) { did in
                ProfileView(actorDID: did)
            }
            // Profiles pushed from search show posts — without this
            // registration, tapping a post did nothing in this stack.
            .navigationDestination(for: PostNavigation.self) { nav in
                PostDetailView(nav: nav)
            }
            // Handle speakwrite://profile/<handle> mention taps in this stack.
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "speakwrite", url.host == "profile",
                   let handle = url.pathComponents.dropFirst().first {
                    path.append(handle)
                    return .handled
                }
                return .systemAction
            })
            .onChange(of: query) { _, newQuery in
                performSearch(query: newQuery)
            }
        }
    }

    private func performSearch(query: String) {
        searchTask?.cancel()

        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }

            do {
                let searchResults = try await viewModel.atproto.searchUsers(query: query)
                await MainActor.run {
                    results = searchResults
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                }
            }
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let profile: ProfileViewBasic
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: Theme.md) {
            AsyncImage(url: profile.avatar.flatMap { URL(string: $0) }) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle()
                    .fill(Theme.surfaceElevated(colorScheme))
                    .overlay {
                        Text(String(profile.handle.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.textSecondary(colorScheme))
                    }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                if let name = profile.displayName, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary(colorScheme))
                }
                Text("@\(profile.handle)")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary(colorScheme))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary(colorScheme))
        }
        .padding(.horizontal, Theme.lg)
        .padding(.vertical, Theme.sm)
    }
}

#if DEBUG
#Preview {
    SearchUsersView()
        .environment(AppViewModel.preview)
}
#endif
