import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var handle = ""
    @State private var customServer = ""
    @State private var useCustomServer = false
    @State private var isLoading = false
    @State private var error: String?

    private var serviceHost: String {
        if useCustomServer {
            let trimmed = customServer.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "https://bsky.social" }
            return trimmed.hasPrefix("https://") ? trimmed : "https://\(trimmed)"
        }
        return "https://bsky.social"
    }

    var body: some View {
        VStack(spacing: Theme.xxxl) {
            Spacer()

            Text("speakwrite")
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.accent)

            Text("prove a human wrote it")
                .font(Theme.monoBody)
                .foregroundStyle(Theme.textSecondary)

            Spacer()

            VStack(spacing: Theme.lg) {
                TextField("handle.bsky.social", text: $handle)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(Theme.monoHeadline)
                    .padding(.horizontal)
                    .accessibilityIdentifier("handle-field")

                // Server toggle
                VStack(spacing: Theme.sm) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            useCustomServer.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(useCustomServer ? "Custom PDS" : "Bluesky (bsky.social)")
                                .font(Theme.mono)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                                .rotationEffect(.degrees(useCustomServer ? 180 : 0))
                        }
                        .foregroundStyle(Theme.textTertiary)
                    }

                    if useCustomServer {
                        TextField("your-pds.example.com", text: $customServer)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(Theme.mono)
                            .padding(.horizontal)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Button {
                    Task { await signIn() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(Theme.textPrimary)
                    } else {
                        Text("Sign in")
                            .font(Theme.monoHeadline)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .foregroundStyle(Theme.onAccent)
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
        .background(Theme.background)
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
            try await viewModel.atproto.signIn(
                handle: handle,
                serviceHost: serviceHost,
                presentationAnchor: window
            )
        } catch let err as ASWebAuthenticationSessionError where err.code == .canceledLogin {
            self.error = nil
        } catch let err as ATProtoError {
            switch err {
            case .notLoggedIn:
                self.error = "Not logged in. Please try again."
            case .authCancelled:
                self.error = nil
            case .handleNotFound:
                self.error = "Handle not found. Check spelling — use your handle (e.g. alice.bsky.social), not email."
            default:
                self.error = err.localizedDescription
            }
        } catch let err as URLError {
            switch err.code {
            case .notConnectedToInternet, .networkConnectionLost:
                self.error = "No internet connection. Check your network and try again."
            case .timedOut:
                self.error = "Connection timed out. Try again."
            default:
                self.error = "Network error. Check your connection and try again."
            }
        } catch is DecodingError {
            self.error = "Sign in failed. Check your handle and try again."
        } catch {
            self.error = "Sign in failed. Check your handle and try again."
        }
        isLoading = false
    }
}

#if DEBUG
#Preview {
    LoginView()
        .environment(AppViewModel.previewLoggedOut)
}
#endif
