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
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 80)

                // Wordmark
                VStack(spacing: Theme.md) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.accent)

                    Text("Speakwrite")
                        .font(.system(.largeTitle, design: .serif).weight(.bold))
                        .foregroundStyle(Theme.ink)

                    Text("Prove a human wrote it.")
                        .font(.system(.title3, design: .serif).italic())
                        .foregroundStyle(Theme.inkSecondary)
                }

                Spacer(minLength: 48)

                // Sign-in form
                VStack(spacing: Theme.lg) {
                    TextField("handle.bsky.social", text: $handle)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(Theme.monoBody)
                        .padding(Theme.lg)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.radiusMd)
                                .fill(Theme.surfaceColor)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.radiusMd)
                                .strokeBorder(Theme.hairline, lineWidth: 1)
                        )
                        .accessibilityIdentifier("handle-field")

                    // Server toggle
                    VStack(spacing: Theme.sm) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                useCustomServer.toggle()
                            }
                        } label: {
                            HStack(spacing: Theme.xs) {
                                Text(useCustomServer ? "Custom PDS" : "Bluesky (bsky.social)")
                                    .font(Theme.subhead)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .rotationEffect(.degrees(useCustomServer ? 180 : 0))
                            }
                            .foregroundStyle(Theme.inkTertiary)
                        }

                        if useCustomServer {
                            TextField("your-pds.example.com", text: $customServer)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .font(Theme.mono)
                                .padding(Theme.md)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.radiusMd)
                                        .fill(Theme.surfaceColor)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.radiusMd)
                                        .strokeBorder(Theme.hairline, lineWidth: 1)
                                )
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
                                    .font(Theme.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.lg)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusMd)
                            .fill(handle.isEmpty ? Theme.accentFill.opacity(0.4) : Theme.accentFill)
                    )
                    .foregroundStyle(Theme.onAccent)
                    .disabled(handle.isEmpty || isLoading)

                    if let error {
                        Text(error)
                            .font(Theme.subhead)
                            .foregroundStyle(Theme.error)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, Theme.xxl)

                Spacer(minLength: 48)

                // What signing in gets you
                VStack(alignment: .leading, spacing: Theme.md) {
                    explainerRow(icon: "keyboard", text: "Type by hand — no paste, no dictation, no AI")
                    explainerRow(icon: "cpu", text: "Your iPhone signs a hardware-backed proof")
                    explainerRow(icon: "checkmark.seal", text: "Anyone can verify it, no server required")
                }
                .padding(.horizontal, Theme.xxl)
                .padding(.bottom, Theme.xxxl)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.bg)
    }

    private func explainerRow(icon: String, text: String) -> some View {
        HStack(spacing: Theme.md) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            Text(text)
                .font(Theme.subhead)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
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
            default:
                self.error = err.localizedDescription
            }
        } catch let err as URLError {
            switch err.code {
            case .notConnectedToInternet, .networkConnectionLost:
                self.error = "No internet connection. Check your network and try again."
            case .timedOut:
                self.error = "Connection timed out. Try again."
            case .cannotConnectToHost, .cannotFindHost, .secureConnectionFailed:
                self.error = "Can't reach your server (PDS). If you self-host, check that it's online."
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
