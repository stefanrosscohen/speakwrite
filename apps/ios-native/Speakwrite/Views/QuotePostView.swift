import SwiftUI

/// Quote-post compose sheet — user writes text above an embedded quoted post card.
struct QuotePostView: View {
    let quotedUri: String
    let quotedCid: String
    let quotedHandle: String
    let quotedDisplayName: String?
    let quotedAvatar: String?
    let quotedText: String

    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var postText = ""
    @State private var isSending = false
    @State private var error: String?

    // @Mention autocomplete
    @State private var mentionQuery: String = ""
    @State private var mentionResults: [ProfileViewBasic] = []
    @State private var showMentionSuggestions = false
    @State private var mentionSearchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Compose area
                HStack(alignment: .top, spacing: 10) {
                    AvatarView(
                        url: viewModel.myProfile?.avatar,
                        handle: viewModel.atproto.handle,
                        size: .medium
                    )

                    // No inputDelegate: routing keystrokes through the shared
                    // view model would overwrite the Compose tab's draft.
                    InputRestrictedEditor(text: $postText, placeholder: "Add your thoughts")
                        .frame(minHeight: 80)
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

                // Quoted post card
                quotedPostCard
                    .padding(.horizontal, Theme.lg)
                    .padding(.top, Theme.sm)

                if let error {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.error)
                        .padding(.horizontal, Theme.lg)
                        .padding(.top, Theme.xs)
                }

                Spacer()
            }
            .background(Theme.background(colorScheme))
            .onChange(of: postText) { _, newText in
                detectMentionQuery(in: newText)
            }
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
                        Button("Post") {
                            Task { await sendQuotePost() }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .disabled(postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    // MARK: - Quoted Post Card

    private var quotedPostCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Author header
            HStack(spacing: 6) {
                AvatarView(url: quotedAvatar, handle: quotedHandle, size: .small)

                if let name = quotedDisplayName, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary(colorScheme))
                        .lineLimit(1)
                }
                Text("@\(quotedHandle)")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary(colorScheme))
                    .lineLimit(1)
            }

            // Quoted text
            Text(quotedText)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textPrimary(colorScheme))
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMd))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusMd)
                .stroke(Theme.separator(colorScheme), lineWidth: 1)
        )
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
        if let atIndex = postText.lastIndex(of: "@") {
            postText = String(postText[..<atIndex]) + "@\(profile.handle) "
        }
        showMentionSuggestions = false
        mentionResults = []
    }

    // MARK: - Send

    private func sendQuotePost() async {
        let text = postText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSending = true
        error = nil
        do {
            try await viewModel.publishQuotePost(
                text: text,
                quotedUri: quotedUri,
                quotedCid: quotedCid
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
    QuotePostView(
        quotedUri: "at://did:plc:alice123/app.bsky.feed.post/3abc123",
        quotedCid: "bafyreiabc123",
        quotedHandle: "alice.bsky.social",
        quotedDisplayName: "Alice Johnson",
        quotedAvatar: nil,
        quotedText: "The AT Protocol is the future of social networking."
    )
    .environment(AppViewModel.preview)
}
#endif
