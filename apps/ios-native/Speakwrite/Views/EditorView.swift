import SwiftUI

/// Main compose screen with keystroke-captured text editor and toolbar.
struct EditorView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showClearConfirm = false
    @State private var showMyProfile = false
    @State private var mentionQuery: String = ""
    @State private var mentionResults: [ProfileViewBasic] = []
    @State private var showMentionSuggestions = false
    @State private var mentionSearchTask: Task<Void, Never>?
    @State private var showViolationBanner = false
    @State private var violationDismissTask: Task<Void, Never>?
    @State private var cameraError: String?

    var body: some View {
        @Bindable var vm = viewModel

        NavigationStack {
            VStack(spacing: 0) {
                AppHeader(onAvatarTap: { showMyProfile = true })

                // Violation banner
                if showViolationBanner {
                    HStack(spacing: Theme.sm) {
                        Image(systemName: "hand.raised.fill")
                            .font(.footnote)
                        Text("Blocked — verified posts are typed by hand on the on-screen keyboard.")
                            .font(Theme.subhead.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, Theme.lg)
                    .padding(.vertical, Theme.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.warning.opacity(0.18))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Editor — placeholder is rendered by InputRestrictedEditor itself
                InputRestrictedEditor(
                    text: $vm.postText,
                    placeholder: "Write it yourself.",
                    inputDelegate: viewModel
                )
                .accessibilityIdentifier("compose-editor")
                .padding(.horizontal, Theme.lg)
                .padding(.top, Theme.sm)

                // Media preview strip (attached photos/video)
                if !viewModel.capturedPhotos.isEmpty || viewModel.capturedVideo != nil {
                    MediaPreviewStrip(
                        photos: viewModel.capturedPhotos,
                        video: viewModel.capturedVideo,
                        onRemovePhoto: { id in
                            viewModel.capturedPhotos.removeAll { $0.id == id }
                        },
                        onRemoveVideo: {
                            viewModel.capturedVideo = nil
                        }
                    )
                }

                // @Mention autocomplete suggestions
                if showMentionSuggestions && !mentionResults.isEmpty {
                    MentionSuggestionList(
                        results: mentionResults,
                        onSelect: { profile in
                            insertMention(profile)
                        }
                    )
                }

                // Compose toolbar
                ComposeToolbar(
                    showClearConfirm: $showClearConfirm,
                    onDismissKeyboard: {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    },
                    onPhotoTap: {
                        viewModel.cameraMode = .photo
                        viewModel.showCamera = true
                    },
                    onVideoTap: {
                        viewModel.cameraMode = .video
                        viewModel.showCamera = true
                    },
                    mediaCount: viewModel.capturedPhotos.count + (viewModel.capturedVideo != nil ? 1 : 0),
                    isPhotoDisabled: viewModel.capturedPhotos.count >= 4 || viewModel.capturedVideo != nil,
                    isVideoDisabled: !viewModel.capturedPhotos.isEmpty || viewModel.capturedVideo != nil
                )

                Divider()
                    .background(Theme.separator(colorScheme))

                // Post bar with character ring + publish
                PostBarView()
            }
            .background(Theme.background(colorScheme))
            .navigationBarHidden(true)
            .sheet(isPresented: $showMyProfile) {
                MyProfileView()
            }
            .alert("Clear post?", isPresented: $showClearConfirm) {
                Button("Clear", role: .destructive) {
                    viewModel.postText = ""
                    viewModel.capturedPhotos = []
                    viewModel.capturedVideo = nil
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete your current draft.")
            }
            .alert("Capture Error", isPresented: Binding(get: { cameraError != nil }, set: { if !$0 { cameraError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(cameraError ?? "")
            }
            .fullScreenCover(isPresented: $vm.showCamera) {
                CameraCaptureView(mode: viewModel.cameraMode, onCapture: { media in
                    if media.mimeType.starts(with: "video/") {
                        viewModel.capturedPhotos = []
                        viewModel.capturedVideo = media
                    } else {
                        viewModel.capturedVideo = nil
                        if viewModel.capturedPhotos.count < 4 {
                            viewModel.capturedPhotos.append(media)
                        }
                    }
                }, onError: { error in
                    cameraError = error
                })
            }
            .onChange(of: viewModel.postText) { _, newText in
                detectMentionQuery(in: newText)
            }
            .onChange(of: viewModel.violationCount) { _, _ in
                violationDismissTask?.cancel()
                withAnimation(.easeInOut(duration: 0.25)) {
                    showViolationBanner = true
                }
                violationDismissTask = Task {
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showViolationBanner = false
                    }
                }
            }
            .onDisappear {
                violationDismissTask?.cancel()
                mentionSearchTask?.cancel()
            }
        }
    }

    // MARK: - @Mention Detection

    private func detectMentionQuery(in text: String) {
        // Find if cursor is in the middle of typing @something
        // Look for the last @ that doesn't have a space after it
        guard let atIndex = text.lastIndex(of: "@") else {
            showMentionSuggestions = false
            return
        }

        let afterAt = text[text.index(after: atIndex)...]
        // If there's a space after the partial handle, dismiss
        if afterAt.contains(" ") || afterAt.contains("\n") {
            showMentionSuggestions = false
            return
        }

        let query = String(afterAt)
        guard query.count >= 1 else {
            showMentionSuggestions = false
            return
        }

        mentionQuery = query

        // Cancel any previous search
        mentionSearchTask?.cancel()
        mentionSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            do {
                let results = try await viewModel.atproto.searchUsersTypeahead(query: query)
                await MainActor.run {
                    mentionResults = results
                    showMentionSuggestions = !results.isEmpty
                }
            } catch {
                await MainActor.run {
                    showMentionSuggestions = false
                }
            }
        }
    }

    private func insertMention(_ profile: ProfileViewBasic) {
        // Replace @partial with @handle
        if let atIndex = viewModel.postText.lastIndex(of: "@") {
            viewModel.postText = String(viewModel.postText[..<atIndex]) + "@\(profile.handle) "
        }
        showMentionSuggestions = false
        mentionResults = []
    }
}

// MARK: - Mention Suggestion List

struct MentionSuggestionList: View {
    let results: [ProfileViewBasic]
    let onSelect: (ProfileViewBasic) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(results) { profile in
                    Button {
                        onSelect(profile)
                    } label: {
                        HStack(spacing: Theme.sm) {
                            AsyncImage(url: profile.avatar.flatMap { URL(string: $0) }) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(Theme.surfaceElevated(colorScheme))
                            }
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                if let name = profile.displayName, !name.isEmpty {
                                    Text(name)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Theme.textPrimary(colorScheme))
                                }
                                Text("@\(profile.handle)")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundStyle(Theme.textSecondary(colorScheme))
                            }

                            Spacer()
                        }
                        .padding(.horizontal, Theme.lg)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .foregroundStyle(Theme.separator(colorScheme))
                }
            }
        }
        .frame(maxHeight: 200)
        .background(Theme.surfaceElevated(colorScheme))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .padding(.horizontal, Theme.lg)
    }
}

// MARK: - Compose Toolbar

struct ComposeToolbar: View {
    @Binding var showClearConfirm: Bool
    var onDismissKeyboard: () -> Void
    var onPhotoTap: () -> Void
    var onVideoTap: () -> Void
    var mediaCount: Int
    var isPhotoDisabled: Bool
    var isVideoDisabled: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: Theme.xl) {
            Button {
                onDismissKeyboard()
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.accent.opacity(0.8))
            }

            Divider()
                .frame(height: 18)

            Menu {
                Button {
                    onPhotoTap()
                } label: {
                    Label("Take Photo", systemImage: "camera")
                }
                .disabled(isPhotoDisabled)

                Button {
                    onVideoTap()
                } label: {
                    Label("Record Video (60s max)", systemImage: "video")
                }
                .disabled(isVideoDisabled)
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "camera")
                        .font(.system(size: 15))
                        .foregroundStyle((isPhotoDisabled && isVideoDisabled) ? Theme.textTertiary(colorScheme) : Theme.accent.opacity(0.8))

                    if mediaCount > 0 {
                        Text("\(mediaCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 14, height: 14)
                            .background(Circle().fill(Theme.accent))
                            .offset(x: 6, y: -6)
                    }
                }
            }

            Divider()
                .frame(height: 18)

            Button {
                showClearConfirm = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary(colorScheme))
            }

            Spacer()
        }
        .padding(.horizontal, Theme.lg)
        .padding(.vertical, 6)
        .accessibilityIdentifier("media-toolbar")
    }
}

#if DEBUG
#Preview {
    EditorView()
        .environment(AppViewModel.preview)
}
#endif
