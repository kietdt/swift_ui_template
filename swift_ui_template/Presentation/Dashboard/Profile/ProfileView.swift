import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(\.openURL) private var openURL
    @State var viewModel: ProfileViewModel

    var body: some View {
        List {
            Section {
                header
            }

            Section("Settings") {
                Button {
                    // iOS shows a per-app Language picker here when the app has 2+ localizations.
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    LabeledContent("Language") {
                        Image(systemName: "arrow.up.forward.app")
                    }
                }
                .tint(.primary)
                LabeledContent("Version", value: viewModel.appVersion)
                LabeledContent("Environment", value: viewModel.environmentName)
            }

            Section {
                Button("Log Out", role: .destructive) {
                    viewModel.isConfirmingLogout = true
                }
            }
        }
        .navigationTitle("Profile")
        .task { await viewModel.load() }
        .confirmationDialog("Log out of your account?", isPresented: $viewModel.isConfirmingLogout, titleVisibility: .visible) {
            Button("Log Out", role: .destructive) {
                Task { await viewModel.logout() }
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
        case .failed(let message):
            VStack(spacing: Theme.Spacing.s) {
                Text(message)
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    Task { await viewModel.retry() }
                }
            }
            .frame(maxWidth: .infinity)
        case .loaded(let user):
            HStack(spacing: Theme.Spacing.m) {
                AsyncImage(url: user.avatarURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(user.fullName)
                        .font(.headline)
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView(viewModel: AppContainer.preview().makeProfileViewModel())
    }
}
