import SwiftUI

struct RootView: View {
    @Environment(AppContainer.self) private var container
    let router: AppRouter

    var body: some View {
        ZStack {
            switch router.route {
            case .launching:
                Color.clear
            case .onboarding:
                OnboardingView(viewModel: container.makeOnboardingViewModel(onFinish: router.onboardingFinished))
                    .transition(.opacity)
            case .login:
                LoginView(viewModel: container.makeLoginViewModel())
                    .transition(.opacity)
            case .main:
                DashboardView()
                    .transition(.opacity)
            }
        }
        .animation(.default, value: router.route)
        .task {
            await router.start()
            await router.observeSession()
        }
    }
}

#Preview {
    let container = AppContainer.preview(isLoggedIn: false)
    RootView(router: container.makeAppRouter())
        .environment(container)
}
