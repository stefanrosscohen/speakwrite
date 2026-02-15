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
    @FocusState private var isEditorFocused: Bool

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

                    TextEditor(text: $postText)
                        .font(.system(size: 16))
                        .scrollContentBackground(.hidden)
                        .focused($isEditorFocused)
                        .frame(minHeight: 80)
                        .overlay(alignment: .topLeading) {
                            if postText.isEmpty {
                                Text("Add your thoughts")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Theme.textTertiary(colorScheme))
                                    .allowsHitTesting(false)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                        }
                }
                .padding(.horizontal, Theme.lg)
                .padding(.top, Theme.md)

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
            .onAppear { isEditorFocused = true }
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

    // MARK: - Send

    private func sendQuotePost() async {
        isSending = true
        error = nil
        do {
            try await viewModel.atproto.quotePost(
                text: postText,
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
