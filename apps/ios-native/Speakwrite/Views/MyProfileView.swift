import SwiftUI

/// Shows the logged-in user's own profile. Presented as a sheet from the avatar button.
struct MyProfileView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Banner
                    if let bannerURL = viewModel.myProfile?.banner, let url = URL(string: bannerURL) {
                        AsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle().fill(Theme.surface(colorScheme))
                        }
                        .frame(height: 150)
                        .clipped()
                    } else {
                        Rectangle()
                            .fill(Theme.surface(colorScheme))
                            .frame(height: 150)
                    }

                    HStack {
                        AvatarView(
                            url: viewModel.myProfile?.avatar,
                            handle: viewModel.myProfile?.handle ?? viewModel.atproto.handle,
                            size: .large
                        )
                        .overlay(Circle().stroke(Theme.avatarBorder(colorScheme), lineWidth: 3))
                        Spacer()
                    }
                    .padding(.horizontal, Theme.lg)
                    .offset(y: -35)
                    .padding(.bottom, -35)

                    VStack(alignment: .leading, spacing: Theme.xs) {
                        if let name = viewModel.myProfile?.displayName, !name.isEmpty {
                            Text(name)
                                .font(Theme.title)
                                .foregroundStyle(Theme.textPrimary(colorScheme))
                        }
                        Text("@\(viewModel.myProfile?.handle ?? viewModel.atproto.handle ?? "")")
                            .font(Theme.mono)
                            .foregroundStyle(Theme.textSecondary(colorScheme))
                    }
                    .padding(.horizontal, Theme.lg)
                    .padding(.top, Theme.sm)

                    if let bio = viewModel.myProfile?.description, !bio.isEmpty {
                        Text(bio)
                            .font(Theme.body)
                            .foregroundStyle(Theme.textPrimary(colorScheme))
                            .padding(.horizontal, Theme.lg)
                            .padding(.top, Theme.sm)
                    }

                    HStack(spacing: Theme.xxl) {
                        StatView(count: viewModel.myProfile?.postsCount ?? 0, label: "Posts")
                        StatView(count: viewModel.myProfile?.followersCount ?? 0, label: "Followers")
                        StatView(count: viewModel.myProfile?.followsCount ?? 0, label: "Following")
                    }
                    .padding(.horizontal, Theme.lg)
                    .padding(.top, Theme.md)

                    Divider()
                        .background(Theme.separator(colorScheme))
                        .padding(.top, Theme.lg)
                }
            }
            .background(Theme.background(colorScheme))
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.monoHeadline)
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }
}
