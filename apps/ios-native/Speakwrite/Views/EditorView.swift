import SwiftUI

/// Main compose screen with keystroke-captured text editor and toolbar.
struct EditorView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showProofSidebar = false
    @State private var showPublishSheet = false
    @State private var showClearConfirm = false
    @State private var showMyProfile = false

    var body: some View {
        @Bindable var vm = viewModel

        NavigationStack {
            VStack(spacing: 0) {
                // Editor area
                ZStack(alignment: .topLeading) {
                    CaptureTextEditor(
                        text: $vm.postText,
                        placeholder: "What's on your mind?",
                        captureDelegate: viewModel.sessionService
                    )

                    // Placeholder text (shown when empty)
                    if viewModel.postText.isEmpty {
                        Text("What's on your mind?")
                            .font(.system(size: 17, design: .monospaced))
                            .foregroundStyle(Theme.textTertiary(colorScheme))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal, Theme.lg)
                .padding(.top, Theme.sm)

                // Compose toolbar
                ComposeToolbar(
                    showClearConfirm: $showClearConfirm,
                    onDismissKeyboard: {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                )

                Divider()
                    .background(Theme.separator(colorScheme))

                // Post bar with character ring + publish
                PostBarView(showPublishSheet: $showPublishSheet)
            }
            .background(Theme.background(colorScheme))
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    AvatarButton(
                        avatarURL: viewModel.myProfile?.avatar,
                        handle: viewModel.atproto.handle
                    ) {
                        showMyProfile = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showProofSidebar.toggle()
                    } label: {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showProofSidebar) {
                ProofSidebarView()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showPublishSheet) {
                PublishView()
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showMyProfile) {
                MyProfileView()
            }
            .alert("Clear post?", isPresented: $showClearConfirm) {
                Button("Clear", role: .destructive) {
                    viewModel.postText = ""
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete your current draft. Keystroke data for this session will be lost.")
            }
            .task {
                await viewModel.startWriting()
            }
        }
    }
}

// MARK: - Compose Toolbar

struct ComposeToolbar: View {
    @Binding var showClearConfirm: Bool
    var onDismissKeyboard: () -> Void
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
    }
}
