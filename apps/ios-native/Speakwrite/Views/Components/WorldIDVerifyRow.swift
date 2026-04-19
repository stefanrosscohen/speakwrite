import SwiftUI

/// Settings row that drives the World ID verification flow.
struct WorldIDVerifyRow: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme

    private var worldID: WorldIDService { viewModel.worldID }

    var body: some View {
        HStack(spacing: Theme.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: 32, height: 32)
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textPrimary(colorScheme))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary(colorScheme))
            }

            Spacer()

            actionView
        }
        .padding(.vertical, 4)
    }

    // MARK: - State-driven properties

    private var iconName: String {
        switch worldID.status {
        case .verified: return "globe.badge.chevron.backward"
        case .verifying: return "ellipsis"
        case .failed: return "exclamationmark.triangle"
        case .notVerified: return "globe"
        }
    }

    private var iconBackground: Color {
        switch worldID.status {
        case .verified: return .green
        case .verifying: return Theme.accent
        case .failed: return .orange
        case .notVerified: return Color(.systemGray3)
        }
    }

    private var title: String {
        switch worldID.status {
        case .verified: return "World ID Verified"
        case .verifying: return "Verifying…"
        case .failed: return "Verification Failed"
        case .notVerified: return "Verify with World ID"
        }
    }

    private var subtitle: String {
        switch worldID.status {
        case .verified(let at):
            let date = ISO8601DateFormatter().date(from: at).map {
                RelativeDateTimeFormatter().localizedString(for: $0, relativeTo: Date())
            } ?? at
            return "Verified \(date)"
        case .verifying:
            return "Waiting for World App…"
        case .failed(let msg):
            return msg
        case .notVerified:
            return "Prove you're a unique human"
        }
    }

    @ViewBuilder
    private var actionView: some View {
        switch worldID.status {
        case .verified:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .verifying:
            ProgressView()
                .tint(Theme.accent)
        case .notVerified, .failed:
            Button {
                guard let did = viewModel.atproto.did else { return }
                worldID.startVerification(did: did)
            } label: {
                Text("Verify")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.accent))
            }
            .buttonStyle(.plain)
        }
    }
}

#if DEBUG
#Preview {
    List {
        WorldIDVerifyRow()
            .listRowBackground(Color(.systemGray6))
    }
    .environment(AppViewModel.preview)
}
#endif
