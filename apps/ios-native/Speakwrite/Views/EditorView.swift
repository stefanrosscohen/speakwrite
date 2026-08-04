import SwiftUI

/// Modal compose screen with keystroke-captured text editor and toolbar.
/// Presented as a full-screen cover from the compose button; the draft
/// persists across dismissals.
struct EditorView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirm = false
    @State private var mentionResults: [ProfileViewBasic] = []
    @State private var showMentionSuggestions = false
    @State private var mentionSearchTask: Task<Void, Never>?
    @State private var showViolationBanner = false
    @State private var violationDismissTask: Task<Void, Never>?
    @State private var cameraError: String?
    @State private var showPublishSuccess = false

    var body: some View {
        @Bindable var vm = viewModel

        ZStack {
            VStack(spacing: 0) {
                // Header: Cancel keeps the draft for later
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(Theme.body)
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityIdentifier("compose-cancel")

                    Spacer()

                    Text("New Post")
                        .font(Theme.monoHeadline)
                        .foregroundStyle(Theme.textPrimary)

                    Spacer()

                    // Balance the Cancel button so the title stays centered
                    Button("Cancel") { }
                        .font(Theme.body)
                        .hidden()
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, Theme.lg)
                .padding(.vertical, Theme.md)

                ThemedDivider()

                // Violation banner
                if showViolationBanner {
                    HStack(spacing: Theme.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(Theme.subhead)
                        Text("Naughty naughty — use the iPhone keyboard to make a verified post")
                            .font(Theme.mono.weight(.medium))
                    }
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, Theme.lg)
                    .padding(.vertical, Theme.sm)
                    .frame(maxWidth: .infinity)
                    .background(Theme.accent.opacity(0.9))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                InputRestrictedEditor(
                    text: $vm.postText,
                    placeholder: "What's on your mind?",
                    inputDelegate: viewModel,
                    resetSignal: viewModel.composeResetSignal
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

                ThemedDivider()

                // Post bar with character ring + publish
                PostBarView()
            }

            if showPublishSuccess {
                PublishSuccessOverlay()
            }
        }
        .background(Theme.background)
        .alert("Clear post?", isPresented: $showClearConfirm) {
            Button("Clear", role: .destructive) {
                viewModel.clearDraft()
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
        .alert("Heads up", isPresented: Binding(
            get: { viewModel.publishWarning != nil },
            set: { if !$0 { viewModel.publishWarning = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.publishWarning ?? "")
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
        .onChange(of: viewModel.violationCount) { _, newCount in
            guard newCount > 0 else { return }
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
        .onChange(of: viewModel.lastPublishedURI) { _, uri in
            guard uri != nil else { return }
            // Show success, then land on the Verified feed where the post appears
            withAnimation(.easeInOut(duration: 0.2)) {
                showPublishSuccess = true
            }
            Task {
                try? await Task.sleep(for: .seconds(1.1))
                viewModel.lastPublishedURI = nil
                viewModel.selectedTab = .verified
                dismiss()
            }
        }
    }

    // MARK: - @Mention Detection

    private func detectMentionQuery(in text: String) {
        // Find if the user is in the middle of typing @something at the end
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
        guard query.count >= 2 else {
            showMentionSuggestions = false
            return
        }

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
        // Replace the trailing @partial token with the selected @handle
        if let atIndex = viewModel.postText.lastIndex(of: "@") {
            viewModel.postText = String(viewModel.postText[..<atIndex]) + "@\(profile.handle) "
        }
        showMentionSuggestions = false
        mentionResults = []
    }
}

// MARK: - Publish Success Overlay

struct PublishSuccessOverlay: View {
    var body: some View {
        VStack(spacing: Theme.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accent)
            Text("Published")
                .font(Theme.monoHeadline)
                .foregroundStyle(Theme.textPrimary)
            Text("Signed by your Secure Enclave")
                .font(Theme.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(Theme.xxl)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusLg)
                .fill(Theme.surfaceElevated)
                .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
        )
        .transition(.scale(scale: 0.9).combined(with: .opacity))
        .accessibilityIdentifier("publish-success")
    }
}

// MARK: - Mention Suggestion List

struct MentionSuggestionList: View {
    let results: [ProfileViewBasic]
    let onSelect: (ProfileViewBasic) -> Void

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
                                Circle().fill(Theme.surfaceElevated)
                            }
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                if let name = profile.displayName, !name.isEmpty {
                                    Text(name)
                                        .font(Theme.subhead.weight(.medium))
                                        .foregroundStyle(Theme.textPrimary)
                                }
                                Text("@\(profile.handle)")
                                    .font(Theme.mono)
                                    .foregroundStyle(Theme.textSecondary)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, Theme.lg)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)

                    ThemedDivider()
                }
            }
        }
        .frame(maxHeight: 200)
        .background(Theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSm))
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

    var body: some View {
        HStack(spacing: Theme.xl) {
            Button {
                onDismissKeyboard()
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(Theme.body)
                    .foregroundStyle(Theme.accent.opacity(0.8))
            }
            .accessibilityLabel("Dismiss keyboard")

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
                        .font(Theme.body)
                        .foregroundStyle((isPhotoDisabled && isVideoDisabled) ? Theme.textTertiary : Theme.accent.opacity(0.8))

                    if mediaCount > 0 {
                        Text("\(mediaCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.onAccent)
                            .frame(width: 14, height: 14)
                            .background(Circle().fill(Theme.accent))
                            .offset(x: 6, y: -6)
                    }
                }
            }
            .accessibilityLabel("Add photo or video")

            Divider()
                .frame(height: 18)

            Button {
                showClearConfirm = true
            } label: {
                Image(systemName: "trash")
                    .font(Theme.body)
                    .foregroundStyle(Theme.textSecondary)
            }
            .accessibilityLabel("Clear draft")

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
