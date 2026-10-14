import SwiftUI

struct LoginView: View {
    @State var viewModel: LoginViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                VStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.tint)
                    Text("Welcome back")
                        .font(.largeTitle.bold())
                    Text("Sign in to continue")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, Theme.Spacing.xl)

                AppTextField(title: "Username", text: $viewModel.username, error: viewModel.usernameError)
                    .textContentType(.username)
                AppTextField(title: "Password", text: $viewModel.password, isSecure: true, error: viewModel.passwordError)
                    .textContentType(.password)

                PrimaryButton(title: "Log In", isLoading: viewModel.isLoading) {
                    Task { await viewModel.submit() }
                }
            }
            .padding(Theme.Spacing.m)
            .disabled(viewModel.isLoading)
        }
        .scrollDismissesKeyboard(.interactively)
        .alert("Login failed", isPresented: $viewModel.isShowingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
    }
}

#Preview {
    LoginView(viewModel: AppContainer.preview(isLoggedIn: false).makeLoginViewModel())
}
