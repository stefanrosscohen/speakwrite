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
                        InputRestrictedEditor(text: $replyText, placeholder: "Post your reply", inputDelegate: nil)
                            .frame(minHeight: 100)
                    }
                }
                .padding(.horizontal, Theme.lg)
                .padding(.top, Theme.md)

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
                        Button("Reply") {
                            Task { await sendReply() }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .disabled(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    // MARK: - Send

    private func sendReply() async {
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSending = true
        error = nil
        do {
            try await viewModel.publishReply(text: text, parentUri: replyToUri, parentCid: replyToCid)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSending = false
    }
}
