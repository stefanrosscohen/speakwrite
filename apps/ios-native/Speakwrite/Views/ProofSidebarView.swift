import SwiftUI

/// Shows proof chain status: keystroke count, commitment chain, session duration.
struct ProofSidebarView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            List {
                Section("Session") {
                    if let session = viewModel.sessionService {
                        LabeledContent("Status") {
                            Text(session.sessionActive ? "Capturing" : "Idle")
                                .foregroundStyle(session.sessionActive ? Theme.accent : Theme.textSecondary(colorScheme))
                        }
                        LabeledContent("Keystrokes") {
                            Text("\(session.keystrokeCount)").monospacedDigit()
                        }
                        LabeledContent("Commitments") {
                            Text("\(session.commitmentCount)").monospacedDigit()
                        }
                    } else {
                        Text("No active session")
                            .foregroundStyle(Theme.textSecondary(colorScheme))
                    }
                }
                .listRowBackground(Theme.surfaceElevated(colorScheme))

                if let session = viewModel.sessionService, !session.commitments.isEmpty {
                    Section("Commitment Chain") {
                        ForEach(session.commitments, id: \.sequenceNum) { commitment in
                            VStack(alignment: .leading, spacing: Theme.xs) {
                                HStack {
                                    Text("#\(commitment.sequenceNum)")
                                        .font(Theme.monoBold)
                                        .foregroundStyle(Theme.accent)
                                    Spacer()
                                    Text(commitment.commitmentType)
                                        .font(Theme.monoSmall)
                                        .foregroundStyle(Theme.textSecondary(colorScheme))
                                }
                                Text(String(commitment.commitmentHash.prefix(16)) + "...")
                                    .font(Theme.monoSmall)
                                    .foregroundStyle(Theme.textSecondary(colorScheme))
                                if let prev = commitment.previousHash {
                                    HStack(spacing: Theme.xs) {
                                        Image(systemName: "arrow.turn.down.right")
                                            .font(.system(size: 10))
                                        Text(String(prev.prefix(16)) + "...")
                                            .font(Theme.monoSmall)
                                    }
                                    .foregroundStyle(Theme.textTertiary(colorScheme))
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .listRowBackground(Theme.surfaceElevated(colorScheme))
                    }
                }

                Section("Device Attestation") {
                    let support = viewModel.attestation.isSupported()
                    LabeledContent("App Attest") {
                        Image(systemName: support.appAttest ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(support.appAttest ? Theme.accent : Theme.error)
                    }
                    LabeledContent("Secure Enclave") {
                        Image(systemName: support.secureEnclave ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(support.secureEnclave ? Theme.accent : Theme.error)
                    }
                }
                .listRowBackground(Theme.surfaceElevated(colorScheme))
            }
            .font(Theme.mono)
            .scrollContentBackground(.hidden)
            .background(Theme.background(colorScheme))
            .navigationTitle("Proof")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
