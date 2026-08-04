import SwiftUI

/// Reply compose sheet — shows original post above the compose area.
struct ReplyView: View {
    let replyToUri: String
    let replyToCid: String
    let replyToHandle: String
    let replyToDisplayName: String?
    let replyToAvatar: String?
    let replyToText: String

    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
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
    @State private var mentionQuery: String = ""
    @State private var mentionResults: [ProfileViewBasic] = []
    @State private var showMentionSuggestions = false
    @State private var mentionSearchTask: Task<Void, Never>?

    private var hasMedia: Bool {
        !capturedPhotos.isEmpty || capturedVideo != nil
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Scrollable content — keeps small screens (iPhone SE) usable with the keyboard up
                ScrollView {
                    scrollableContent
                }

                // Pinned action bar
                actionBar

                if let error {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.error)
                        .padding(.horizontal, Theme.lg)
                        .padding(.bottom, Theme.xs)
                }
            }
            .background(Theme.background(colorScheme))
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 16))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSending {
                        ProgressView().tint(Theme.accent)
                    } else {
                        Button("Reply") {
                            Task { await sendReply() }
                        }
                        .font(.system(size: 16, weight: .semibold))
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

    // MARK: - Scrollable Content

    private var scrollableContent: some View {
        VStack(alignment: .leading, spacing: 0) {
                // Original post + reply compose as a continuous thread
                HStack(alignment: .top, spacing: 10) {
                    // Left column: avatars + thread connector
                    VStack(spacing: 4) {
                        AvatarView(url: replyToAvatar, handle: replyToHandle, size: .medium)

                        // Thread connector line
                        Rectangle()
                            .fill(Theme.separator(colorScheme))
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
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary(colorScheme))
                                    .lineLimit(1)
                            }
                            Text("@\(replyToHandle)")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textSecondary(colorScheme))
                                .lineLimit(1)
                        }

                        // Original post text
                        Text(replyToText)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textPrimary(colorScheme))
                            .lineLimit(6)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)

                        // "Replying to" label
                        HStack(spacing: 4) {
                            Text("Replying to")
                                .foregroundStyle(Theme.textTertiary(colorScheme))
                            Text("@\(replyToHandle)")
                                .foregroundStyle(Theme.accent)
                        }
                        .font(.system(size: 14))
                        .padding(.top, 8)
                        .padding(.bottom, 12)

                        // Compose area — flows right after the thread connector
                        InputRestrictedEditor(text: $replyText, placeholder: "Post your reply", inputDelegate: viewModel)
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
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary(colorScheme))
                    }
                    .padding(.horizontal, Theme.lg)
                    .padding(.top, Theme.xs)
                }

        }
    }

    // MARK: - Action Bar (pinned)

    private var actionBar: some View {
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
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.accent.opacity(0.8))

                            let mediaCount = capturedPhotos.count + (capturedVideo != nil ? 1 : 0)
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

                    Spacer()
                }
        .padding(.horizontal, Theme.lg)
        .padding(.vertical, 6)
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

        mentionQuery = query
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
                capturedPhotos: capturedPhotos,
                capturedVideo: capturedVideo,
                onVideoStatus: { status in
                    videoProcessingStatus = status
                }
            )
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSending = false
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
