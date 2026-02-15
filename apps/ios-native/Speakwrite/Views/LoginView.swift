import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var handle = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: Theme.xxxl) {
            Spacer()

            Text("speakwrite")
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.accent)

            Text("prove a human wrote it")
                .font(Theme.monoBody)
                .foregroundStyle(Theme.textSecondary(colorScheme))

            Spacer()

            VStack(spacing: Theme.lg) {
                TextField("your.bsky.handle", text: $handle)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(Theme.monoHeadline)
                    .padding(.horizontal)

                Button {
                    Task { await signIn() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(Theme.textPrimary(colorScheme))
                    } else {
                        Text("Sign in with Bluesky")
                            .font(Theme.monoHeadline)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .foregroundStyle(.black)
                .disabled(handle.isEmpty || isLoading)
                .padding(.horizontal)

                if let error {
                    Text(error)
                        .font(Theme.mono)
                        .foregroundStyle(Theme.error)
                        .padding(.horizontal)
                }
            }

            Spacer()
        }
        .background(Theme.background(colorScheme))
    }

    private func signIn() async {
        isLoading = true
        error = nil
        do {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows.first else {
                throw ATProtoError.authCancelled
            }
            try await viewModel.atproto.signIn(handle: handle, presentationAnchor: window)
        } catch let err as ASWebAuthenticationSessionError where err.code == .canceledLogin {
            self.error = nil // User cancelled — don't show error
        } catch {
            self.error = "\(error)"
        }
        isLoading = false
    }
}
