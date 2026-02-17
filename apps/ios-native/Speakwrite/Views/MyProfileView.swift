import PhotosUI
import SwiftUI

/// Shows the logged-in user's own profile with posts, edit, and delete capabilities.
struct MyProfileView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var posts: [TimelinePost] = []
    @State private var postsCursor: String?
    @State private var isLoading = true
    @State private var showEditProfile = false
    @State private var postToDelete: TimelinePost?
    @State private var showDeleteConfirm = false

    // Photo pickers
    @State private var avatarItem: PhotosPickerItem?
    @State private var bannerItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var isUploadingBanner = false

    var body: some View {
        NavigationStack {
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
                                        Rectangle().fill(Theme.surface(colorScheme))
                                    }
                                }
                                .clipped()
                                .overlay(alignment: .bottomTrailing) {
                                    bannerOverlayIcon
                                }
                        } else {
                            Rectangle()
                                .fill(Theme.surface(colorScheme))
                                .frame(height: 150)
                                .overlay {
                                    if isUploadingBanner {
                                        ProgressView().tint(Theme.accent)
                                    } else {
                                        Image(systemName: "camera")
                                            .foregroundStyle(Theme.textTertiary(colorScheme))
                                            .font(.system(size: 24))
                                    }
                                }
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
                            .overlay(Circle().stroke(Theme.avatarBorder(colorScheme), lineWidth: 3))
                            .overlay(alignment: .bottomTrailing) {
                                if isUploadingAvatar {
                                    ProgressView()
                                        .tint(Theme.accent)
                                        .frame(width: 24, height: 24)
                                        .background(Theme.background(colorScheme))
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "camera.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(Theme.accent)
                                        .background(Theme.background(colorScheme))
                                        .clipShape(Circle())
                                }
                            }
                        }

                        Spacer()

                        Button {
                            showEditProfile = true
                        } label: {
                            Text("Edit Profile")
                                .font(.system(size: 14, weight: .semibold))
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
                                .foregroundStyle(Theme.textPrimary(colorScheme))
                        }
                        Text("@\(viewModel.myProfile?.handle ?? viewModel.atproto.handle ?? "")")
                            .font(Theme.mono)
                            .foregroundStyle(Theme.textSecondary(colorScheme))
                    }
                    .padding(.horizontal, Theme.lg)
                    .padding(.top, Theme.sm)

                    // Bio
                    if let bio = viewModel.myProfile?.description, !bio.isEmpty {
                        Text(bio)
                            .font(Theme.body)
                            .foregroundStyle(Theme.textPrimary(colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, Theme.lg)
                            .padding(.top, Theme.sm)
                    }

                    // Stats
                    HStack(spacing: Theme.xxl) {
                        StatView(count: viewModel.myProfile?.postsCount ?? 0, label: "Posts")
                        StatView(count: viewModel.myProfile?.followersCount ?? 0, label: "Followers")
                        StatView(count: viewModel.myProfile?.followsCount ?? 0, label: "Following")
                    }
                    .padding(.horizontal, Theme.lg)
                    .padding(.top, Theme.md)

                    Divider()
                        .foregroundStyle(Theme.separator(colorScheme))
                        .padding(.top, Theme.lg)

                    // Posts list
                    if isLoading {
                        ProgressView()
                            .tint(Theme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Theme.xxxl)
                    } else if posts.isEmpty {
                        Text("No posts yet")
                            .font(Theme.subhead)
                            .foregroundStyle(Theme.textTertiary(colorScheme))
                            .frame(maxWidth: .infinity)
                            .padding(.top, Theme.xxxl)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(posts) { post in
                                PostRow(post: post)
                                    .padding(.horizontal, Theme.lg)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            postToDelete = post
                                            showDeleteConfirm = true
                                        } label: {
                                            Label("Delete Post", systemImage: "trash")
                                        }
                                    }

                                Divider()
                                    .foregroundStyle(Theme.separator(colorScheme))
                            }

                            if postsCursor != nil {
                                ProgressView()
                                    .tint(Theme.accent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Theme.xl)
                                    .onAppear { Task { await loadMorePosts() } }
                            }
                        }
                    }
                }
            }
            .background(Theme.background(colorScheme))
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.monoHeadline)
                        .foregroundStyle(Theme.accent)
                }
            }
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
                await loadPosts()
            }
            .refreshable {
                await viewModel.loadMyProfile()
                await loadPosts()
            }
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
        do {
            let result = try await viewModel.atproto.getAuthorFeed(actor: did)
            posts = result.posts
            postsCursor = result.cursor
        } catch {}
        isLoading = false
    }

    private func loadMorePosts() async {
        guard let did = viewModel.atproto.did, let cursor = postsCursor else { return }
        do {
            let result = try await viewModel.atproto.getAuthorFeed(actor: did, cursor: cursor)
            posts.append(contentsOf: result.posts)
            postsCursor = result.cursor
        } catch {}
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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Display Name") {
                    TextField("Display name", text: $displayName)
                        .font(Theme.body)
                }
                .listRowBackground(Theme.surfaceElevated(colorScheme))

                Section("Bio") {
                    TextEditor(text: $bio)
                        .font(Theme.body)
                        .frame(minHeight: 100)
                }
                .listRowBackground(Theme.surfaceElevated(colorScheme))

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(Theme.monoSmall)
                            .foregroundStyle(Theme.error)
                    }
                    .listRowBackground(Theme.surfaceElevated(colorScheme))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background(colorScheme))
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary(colorScheme))
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
