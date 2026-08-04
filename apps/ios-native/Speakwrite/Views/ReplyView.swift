import SwiftUI

/// Reply compose sheet — shows original post above the compose area.
struct ReplyView: View {
    let replyToUri: String
    let replyToCid: String
    let replyToHandle: String
    let replyToDisplayName: String?
    let replyToAvatar: String?
    let replyToText: String
    /// Thread root refs — pass the parent's own root when replying to a reply,
    /// so the new post stays in the original thread.
    var rootUri: String?
    var rootCid: String?

    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var replyText = ""
    @State private var isSending = false
    @State private var error: String?

    // Media capture state
    @State private var capturedPhotos: [CapturedMedia] = []
    @State private var capturedVideo: CapturedMedia? = nil
    @State private var showCamera = false
    @State private var cameraMode: CameraMode = .photo
    @State private var videoProcessingStatus: String? = nil

    // @Mention autocomplete
    @State private var mentionResults: [ProfileViewBasic] = []
    @State private var showMentionSuggestions = false
    @State private var mentionSearchTask: Task<Void, Never>?

    private var hasMedia: Bool {
        !capturedPhotos.isEmpty || capturedVideo != nil
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Original post + reply compose as a continuous thread
                HStack(alignment: .top, spacing: 10) {
                    // Left column: avatars + thread connector
                    VStack(spacing: 4) {
                        AvatarView(url: replyToAvatar, handle: replyToHandle, size: .medium)

                        // Thread connector line
                        Rectangle()
                            .fill(Theme.separator)
                            .frame(width: 2, height: 20)

                        AvatarView(
                            url: viewModel.myProfile?.avatar,
                            handle: viewModel.atproto.handle,
                            size: .medium
                        )
                    }

                    // Right column: original post text then compose
                    VStack(alignment: .leading, spacing: 0) {
                        // Author header
                        HStack(spacing: 4) {
                            if let name = replyToDisplayName, !name.isEmpty {
                                Text(name)
                                    .font(Theme.bodyEmphasis)
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(1)
                            }
                            Text("@\(replyToHandle)")
                                .font(Theme.subhead)
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }

                        // Original post text
                        Text(replyToText)
                            .font(Theme.body)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(6)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)

                        // "Replying to" label
                        HStack(spacing: 4) {
                            Text("Replying to")
                                .foregroundStyle(Theme.textTertiary)
                            Text("@\(replyToHandle)")
                                .foregroundStyle(Theme.accent)
                        }
                        .font(Theme.subhead)
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                        // Compose area — flows right after the thread connector.
                        // No inputDelegate: the sheet keeps its own text state and
                        // must not write into the main compose draft.
                        InputRestrictedEditor(text: $replyText, placeholder: "Post your reply")
                            .frame(minHeight: 100)
                    }
                }
                .padding(.horizontal, Theme.lg)
                .padding(.top, Theme.md)

                // @Mention autocomplete suggestions
                if showMentionSuggestions && !mentionResults.isEmpty {
                    MentionSuggestionList(
                        results: mentionResults,
                        onSelect: { profile in
                            insertMention(profile)
                        }
                    )
                }

                // Media preview strip
                if hasMedia {
                    MediaPreviewStrip(
                        photos: capturedPhotos,
                        video: capturedVideo,
                        onRemovePhoto: { id in
                            capturedPhotos.removeAll { $0.id == id }
                        },
                        onRemoveVideo: {
                            capturedVideo = nil
                        }
                    )
                }

                // Video processing status
                if let status = videoProcessingStatus {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(status)
                            .font(Theme.subhead)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, Theme.lg)
                    .padding(.top, Theme.xs)
                }

                // Camera menu
                HStack(spacing: Theme.xl) {
                    Menu {
                        Button {
                            cameraMode = .photo
                            showCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                        }
                        .disabled(capturedPhotos.count >= 4 || capturedVideo != nil)

                        Button {
                            cameraMode = .video
                            showCamera = true
                        } label: {
                            Label("Record Video", systemImage: "video")
                        }
                        .disabled(!capturedPhotos.isEmpty || capturedVideo != nil)
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "camera")
                                .font(Theme.body)
                                .foregroundStyle(Theme.accent.opacity(0.8))

                            let mediaCount = capturedPhotos.count + (capturedVideo != nil ? 1 : 0)
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

                    Spacer()
                }
                .padding(.horizontal, Theme.lg)
                .padding(.vertical, 6)

                if let error {
                    Text(error)
                        .font(Theme.subhead)
                        .foregroundStyle(Theme.error)
                        .padding(.horizontal, Theme.lg)
                        .padding(.top, Theme.xs)
                }

                Spacer()
            }
            .background(Theme.background)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(Theme.body)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSending {
                        ProgressView().tint(Theme.accent)
                    } else {
                        Button("Reply") {
                            Task { await sendReply() }
                        }
                        .font(Theme.headline)
                        .foregroundStyle(Theme.accent)
                        .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasMedia)
                    }
                }
            }
            .onChange(of: replyText) { _, newText in
                detectMentionQuery(in: newText)
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraCaptureView(mode: cameraMode, onCapture: { media in
                    if media.mimeType.starts(with: "video/") {
                        capturedPhotos = []
                        capturedVideo = media
                    } else {
                        capturedVideo = nil
                        if capturedPhotos.count < 4 {
                            capturedPhotos.append(media)
                        }
                    }
                }, onError: { message in
                    error = message
                })
            }
        }
    }

    // MARK: - @Mention Detection

    private func detectMentionQuery(in text: String) {
        guard let atIndex = text.lastIndex(of: "@") else {
            showMentionSuggestions = false
            return
        }

        let afterAt = text[text.index(after: atIndex)...]
        if afterAt.contains(" ") || afterAt.contains("\n") {
            showMentionSuggestions = false
            return
        }

        let query = String(afterAt)
        guard query.count >= 1 else {
            showMentionSuggestions = false
            return
        }

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
        if let atIndex = replyText.lastIndex(of: "@") {
            replyText = String(replyText[..<atIndex]) + "@\(profile.handle) "
        }
        showMentionSuggestions = false
        mentionResults = []
    }

    // MARK: - Send

    private func sendReply() async {
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || hasMedia else { return }
        isSending = true
        error = nil
        do {
            try await viewModel.publishReply(
                text: text,
                parentUri: replyToUri,
                parentCid: replyToCid,
                rootUri: rootUri,
                rootCid: rootCid,
                capturedPhotos: capturedPhotos,
                capturedVideo: capturedVideo,
                onVideoStatus: { status in
                    videoProcessingStatus = status
                }
            )
            isSending = false
            dismiss()
        } catch {
            self.error = error.localizedDescription
            isSending = false
        }
    }
}

#if DEBUG
#Preview {
    ReplyView(
        replyToUri: "at://did:plc:alice123/app.bsky.feed.post/3abc123",
        replyToCid: "bafyreiabc123",
        replyToHandle: "alice.bsky.social",
        replyToDisplayName: "Alice Johnson",
        replyToAvatar: nil,
        replyToText: "Just shipped a new feature! Human-verified posting is now live."
    )
    .environment(AppViewModel.preview)
}
#endif
