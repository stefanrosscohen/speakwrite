import PhotosUI
import SwiftUI

/// The Profile tab — the logged-in user's own profile with posts, edit,
/// delete, and a path into Settings.
struct MyProfileView: View {
    @Environment(AppViewModel.self) private var viewModel

    @State private var posts: [TimelinePost] = []
    @State private var postsCursor: String?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showEditProfile = false
    @State private var postToDelete: TimelinePost?
    @State private var showDeleteConfirm = false
    @State private var path = NavigationPath()

    // Photo pickers
    @State private var avatarItem: PhotosPickerItem?
    @State private var bannerItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var isUploadingBanner = false

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                TabHeader("Profile") {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(Theme.body)
                            .foregroundStyle(Theme.accent)
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("settings-button")
                }

                ThemedDivider()

                profileScroll
            }
            .background(Theme.background)
            .navigationBarHidden(true)
            .navigationDestination(for: String.self) { did in
                ProfileView(actorDID: did)
            }
            .navigationDestination(for: PostNavigation.self) { nav in
                PostDetailView(nav: nav)
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet()
            }
            .alert("Delete this post?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    if let post = postToDelete {
                        Task { await deletePost(post) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the post from your account.")
            }
            .onChange(of: avatarItem) { _, newItem in
                guard let newItem else { return }
                Task { await uploadAvatar(item: newItem) }
            }
            .onChange(of: bannerItem) { _, newItem in
                guard let newItem else { return }
                Task { await uploadBanner(item: newItem) }
            }
            .task {
                await viewModel.loadMyProfile()
                await loadPosts()
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

    private var profileScroll: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Banner
                    PhotosPicker(selection: $bannerItem, matching: .images) {
                        if let bannerURL = viewModel.myProfile?.banner, let url = URL(string: bannerURL) {
                            Color.clear
                                .frame(height: 150)
                                .frame(maxWidth: .infinity)
                                .background {
                                    AsyncImage(url: url) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle().fill(Theme.surface)
                                    }
                                }
                                .clipped()
                                .overlay(alignment: .bottomTrailing) {
                                    bannerOverlayIcon
                                }
                                .accessibilityLabel("Change banner photo")
                        } else {
                            Rectangle()
                                .fill(Theme.surface)
                                .frame(height: 150)
                                .overlay {
                                    if isUploadingBanner {
                                        ProgressView().tint(Theme.accent)
                                    } else {
                                        Image(systemName: "camera")
                                            .foregroundStyle(Theme.textTertiary)
                                            .font(.system(size: 24))
                                    }
                                }
                                .accessibilityLabel("Change banner photo")
                        }
                    }

                    // Avatar + Edit Profile button
                    HStack {
                        PhotosPicker(selection: $avatarItem, matching: .images) {
                            AvatarView(
                                url: viewModel.myProfile?.avatar,
                                handle: viewModel.myProfile?.handle ?? viewModel.atproto.handle,
                                size: .large
                            )
                            .overlay(Circle().stroke(Theme.background, lineWidth: 3))
                            .overlay(alignment: .bottomTrailing) {
                                if isUploadingAvatar {
                                    ProgressView()
                                        .tint(Theme.accent)
                                        .frame(width: 24, height: 24)
                                        .background(Theme.background)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "camera.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(Theme.accent)
                                        .background(Theme.background)
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .accessibilityLabel("Change profile photo")

                        Spacer()

                        Button {
                            showEditProfile = true
                        } label: {
                            Text("Edit Profile")
                                .font(Theme.subhead.weight(.semibold))
                                .padding(.horizontal, Theme.xl)
                                .padding(.vertical, Theme.sm)
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.accent)
                    }
                    .padding(.horizontal, Theme.lg)
                    .padding(.top, Theme.md)

                    // Name + handle
                    VStack(alignment: .leading, spacing: Theme.xs) {
                        if let name = viewModel.myProfile?.displayName, !name.isEmpty {
                            Text(name)
                                .font(Theme.title)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        Text("@\(viewModel.myProfile?.handle ?? viewModel.atproto.handle ?? "")")
                            .font(Theme.mono)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, Theme.lg)
                    .padding(.top, Theme.sm)

                    // Bio
                    if let bio = viewModel.myProfile?.description, !bio.isEmpty {
                        Text(bio)
                            .font(Theme.body)
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, Theme.lg)
                            .padding(.top, Theme.sm)
                    }

                    // Stats
                    HStack(spacing: Theme.xl) {
                        ProfileStat(count: viewModel.myProfile?.postsCount ?? 0, label: "posts")
                        ProfileStat(count: viewModel.myProfile?.followersCount ?? 0, label: "followers")
                        ProfileStat(count: viewModel.myProfile?.followsCount ?? 0, label: "following")
                    }
                    .padding(.horizontal, Theme.lg)
                    .padding(.top, Theme.md)
                    .accessibilityIdentifier("my-profile-header")

                    ThemedDivider()
                        .padding(.top, Theme.lg)

                    // Posts list
                    if isLoading {
                        ProgressView("Loading posts…")
                            .tint(Theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Theme.xxxl)
                    } else if let loadError, posts.isEmpty {
                        ErrorStateView(message: loadError) {
                            Task { await loadPosts() }
                        }
                    } else if posts.isEmpty {
                        Text("No posts yet")
                            .font(Theme.subhead)
                            .foregroundStyle(Theme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Theme.xxxl)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(posts) { post in
                                VStack(spacing: 0) {
                                    PostRow(post: post, hideFollowButton: true)
                                        .padding(.horizontal, Theme.lg)
                                        .overlay(alignment: .topTrailing) {
                                            Menu {
                                                Button(role: .destructive) {
                                                    postToDelete = post
                                                    showDeleteConfirm = true
                                                } label: {
                                                    Label("Delete Post", systemImage: "trash")
                                                }
                                            } label: {
                                                Image(systemName: "ellipsis")
                                                    .font(Theme.subhead)
                                                    .foregroundStyle(Theme.textTertiary)
                                                    .frame(width: 32, height: 32)
                                                    .contentShape(Rectangle())
                                            }
                                            .accessibilityLabel("More options")
                                            .padding(.trailing, Theme.lg)
                                            .padding(.top, 10)
                                        }

                                    ThemedDivider()
                                }
                            }

                            if postsCursor != nil {
                                ProgressView("Loading more…")
                                    .tint(Theme.accent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Theme.xl)
                                    .onAppear { Task { await loadMorePosts() } }
                            }
                        }
                    }
                }
            }
        .refreshable {
            await viewModel.loadMyProfile()
            await loadPosts()
        }
    }

    // MARK: - Banner overlay icon

    private var bannerOverlayIcon: some View {
        Group {
            if isUploadingBanner {
                ProgressView()
                    .tint(.white)
                    .padding(Theme.sm)
            } else {
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(Theme.sm)
            }
        }
    }

    // MARK: - Data Loading

    private func loadPosts() async {
        guard let did = viewModel.atproto.did else { return }
        isLoading = true
        loadError = nil
        do {
            let result = try await viewModel.atproto.getAuthorFeed(actor: did)
            posts = result.posts
            postsCursor = result.cursor
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    private func loadMorePosts() async {
        guard let did = viewModel.atproto.did, let cursor = postsCursor else { return }
        do {
            let result = try await viewModel.atproto.getAuthorFeed(actor: did, cursor: cursor)
            posts.append(contentsOf: result.posts)
            postsCursor = result.cursor
        } catch {
            // Pagination failure is non-critical
        }
    }

    // MARK: - Actions

    private func deletePost(_ post: TimelinePost) async {
        do {
            try await viewModel.atproto.deletePost(uri: post.uri)
            posts.removeAll { $0.uri == post.uri }
        } catch {
            print("[Profile] Failed to delete post: \(error)")
        }
    }

    private func uploadAvatar(item: PhotosPickerItem) async {
        isUploadingAvatar = true
        defer { isUploadingAvatar = false; avatarItem = nil }

        guard let data = try? await item.loadTransferable(type: Data.self) else { return }

        // Compress to JPEG
        guard let uiImage = UIImage(data: data),
              let jpegData = uiImage.jpegData(compressionQuality: 0.8) else { return }

        do {
            let blob = try await viewModel.atproto.uploadBlob(imageData: jpegData, mimeType: "image/jpeg")
            try await viewModel.atproto.updateProfile(avatar: blob)
            await viewModel.loadMyProfile()
        } catch {
            print("[Profile] Failed to upload avatar: \(error)")
        }
    }

    private func uploadBanner(item: PhotosPickerItem) async {
        isUploadingBanner = true
        defer { isUploadingBanner = false; bannerItem = nil }

        guard let data = try? await item.loadTransferable(type: Data.self) else { return }

        guard let uiImage = UIImage(data: data),
              let jpegData = uiImage.jpegData(compressionQuality: 0.8) else { return }

        do {
            let blob = try await viewModel.atproto.uploadBlob(imageData: jpegData, mimeType: "image/jpeg")
            try await viewModel.atproto.updateProfile(banner: blob)
            await viewModel.loadMyProfile()
        } catch {
            print("[Profile] Failed to upload banner: \(error)")
        }
    }
}

// MARK: - Edit Profile Sheet

struct EditProfileSheet: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let displayNameLimit = 64
    private let bioLimit = 256

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Display name", text: $displayName)
                        .font(Theme.body)
                        .onChange(of: displayName) { _, newVal in
                            if newVal.count > displayNameLimit { displayName = String(newVal.prefix(displayNameLimit)) }
                        }
                } header: {
                    Text("Display Name")
                } footer: {
                    Text("\(displayName.count)/\(displayNameLimit)")
                        .font(Theme.monoSmall)
                        .foregroundStyle(displayName.count >= displayNameLimit ? Theme.error : Theme.textTertiary)
                }
                .listRowBackground(Theme.surfaceElevated)

                Section {
                    TextEditor(text: $bio)
                        .font(Theme.body)
                        .frame(minHeight: 100)
                        .onChange(of: bio) { _, newVal in
                            if newVal.count > bioLimit { bio = String(newVal.prefix(bioLimit)) }
                        }
                } header: {
                    Text("Bio")
                } footer: {
                    Text("\(bio.count)/\(bioLimit)")
                        .font(Theme.monoSmall)
                        .foregroundStyle(bio.count >= bioLimit ? Theme.error : Theme.textTertiary)
                }
                .listRowBackground(Theme.surfaceElevated)

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(Theme.monoSmall)
                            .foregroundStyle(Theme.error)
                    }
                    .listRowBackground(Theme.surfaceElevated)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await saveProfile() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(Theme.accent)
                        } else {
                            Text("Save")
                                .font(Theme.monoHeadline)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                displayName = viewModel.myProfile?.displayName ?? ""
                bio = viewModel.myProfile?.description ?? ""
            }
        }
    }

    private func saveProfile() async {
        isSaving = true
        errorMessage = nil
        do {
            try await viewModel.atproto.updateProfile(
                displayName: displayName,
                description: bio
            )
            await viewModel.loadMyProfile()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

#if DEBUG
#Preview {
    MyProfileView()
        .environment(AppViewModel.preview)
}
#endif
