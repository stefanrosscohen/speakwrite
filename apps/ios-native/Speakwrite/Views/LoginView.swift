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
        VStack(spacing: 0) {
            Spacer()

            // Hero
            VStack(spacing: Theme.md) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.accent)

                Text("speakwrite")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.primaryText)

                Text("Prove a human wrote it.")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
            }

            // How it works — three beats, one line each
            VStack(alignment: .leading, spacing: Theme.md) {
                heroPoint(icon: "keyboard", text: "Type it yourself — no paste, no dictation")
                heroPoint(icon: "cpu", text: "Signed by your iPhone's Secure Enclave")
                heroPoint(icon: "checkmark.seal", text: "Anyone can verify it, no server involved")
            }
            .padding(.top, Theme.xxxl)

            Spacer()

            // Sign in
            VStack(spacing: Theme.lg) {
                TextField("handle.bsky.social", text: $handle)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .font(Theme.monoHeadline)
                    .padding(Theme.lg)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusMd)
                            .fill(Theme.surfaceColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMd)
                            .stroke(Theme.divider, lineWidth: 1)
                    )
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
                        .foregroundStyle(Theme.tertiaryText)
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
                    Group {
                        if isLoading {
                            ProgressView()
                                .tint(Theme.onAccent)
                        } else {
                            Text("Sign in")
                                .font(Theme.monoHeadline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .foregroundStyle(Theme.onAccent)
                .disabled(handle.isEmpty || isLoading)
                .padding(.horizontal)

                if let error {
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.error)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                }
            }

            Spacer()
        }
        .background(Theme.backgroundColor)
    }

    private func heroPoint(icon: String, text: String) -> some View {
        HStack(spacing: Theme.md) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondaryText)
        }
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
                handle: handle.trimmingCharacters(in: .whitespacesAndNewlines),
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
            case .pdsUnreachable:
                self.error = err.localizedDescription
            default:
                self.error = err.localizedDescription
            }
        } catch let err as URLError {
            switch err.code {
            case .notConnectedToInternet, .networkConnectionLost:
                self.error = "No internet connection. Check your network and try again."
            case .timedOut:
                self.error = "Connection timed out. Your data server may be down — try again."
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
