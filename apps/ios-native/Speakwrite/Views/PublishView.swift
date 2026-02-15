import SwiftUI

/// Publish confirmation sheet — previews the post and publishes with proof.
struct PublishView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.xl) {
                VStack(alignment: .leading, spacing: Theme.sm) {
                    Text("Preview")
                        .font(Theme.monoBold)
                        .foregroundStyle(Theme.textSecondary(colorScheme))

                    Text(viewModel.postText)
                        .font(Theme.monoBody)
                        .foregroundStyle(Theme.textPrimary(colorScheme))
                        .lineLimit(8)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surface(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSm))
                }
                .padding(.horizontal)

                if let session = viewModel.sessionService {
                    HStack(spacing: Theme.xxl) {
                        PublishStatBadge(label: "keystrokes", value: "\(session.keystrokeCount)")
                        PublishStatBadge(label: "commitments", value: "\(session.commitmentCount)")
                        PublishStatBadge(label: "words", value: "\(viewModel.postText.split(separator: " ").count)")
                    }
                }

                Spacer()

                if viewModel.isPublishing {
                    ProgressView("Publishing...")
                        .font(Theme.mono)
                } else if let uri = viewModel.lastPublishedURI {
                    VStack(spacing: Theme.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.accent)
                        Text("Published!")
                            .font(Theme.monoHeadline)
                            .foregroundStyle(Theme.accent)
                        Text(uri)
                            .font(Theme.monoSmall)
                            .foregroundStyle(Theme.textSecondary(colorScheme))
                            .lineLimit(1)
                    }
                } else {
                    Button {
                        Task { await viewModel.publish() }
                    } label: {
                        Text("Publish to Bluesky")
                            .font(Theme.monoHeadline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .foregroundStyle(.black)
                    .padding(.horizontal)
                }

                if let error = viewModel.publishError {
                    Text(error)
                        .font(Theme.mono)
                        .foregroundStyle(Theme.error)
                        .padding(.horizontal)
                }
            }
            .padding(.top)
            .background(Theme.background(colorScheme))
            .navigationTitle("Publish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.mono)
                }
            }
        }
    }
}

private struct PublishStatBadge: View {
    let label: String
    let value: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: Theme.xs) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.accent)
            Text(label)
                .font(Theme.monoSmall)
                .foregroundStyle(Theme.textSecondary(colorScheme))
        }
    }
}
