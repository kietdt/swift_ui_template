import Foundation
import Observation

/// Composition root: the only place that knows concrete Data types.
/// Views read it with `@Environment(AppContainer.self)` and call the `make…` factories.
@Observable
final class AppContainer {
    let environment: AppEnvironment
    let authRepository: any AuthRepository
    let productRepository: any ProductRepository
    let onboardingRepository: any OnboardingRepository

    init(
        environment: AppEnvironment,
        authRepository: any AuthRepository,
        productRepository: any ProductRepository,
        onboardingRepository: any OnboardingRepository
    ) {
        self.environment = environment
        self.authRepository = authRepository
        self.productRepository = productRepository
        self.onboardingRepository = onboardingRepository
    }

    static func live(environment: AppEnvironment = .current) -> AppContainer {
        let onboardingRepository = LocalOnboardingRepository(store: UserDefaultsStore())

        if environment.useMockData {
            return AppContainer(
                environment: environment,
                authRepository: MockAuthRepository(),
                productRepository: MockProductRepository(),
                onboardingRepository: onboardingRepository
            )
        }

        let session = URLSession(configuration: .default)
        let tokenStore = TokenStore(keychain: SystemKeychainStore(service: Bundle.main.bundleIdentifier ?? "app"))
        let events = SessionEventBroadcaster()
        let refreshClient = URLSessionAPIClient(baseURL: environment.baseURL, session: session, tokenProvider: tokenStore)
        let refresher = TokenRefresher(
            tokenProvider: tokenStore,
            refreshAction: AuthRefreshAction.make(using: refreshClient),
            onSessionExpired: { events.send(.expired) }
        )
        let apiClient = URLSessionAPIClient(
            baseURL: environment.baseURL,
            session: session,
            tokenProvider: tokenStore,
            refresher: refresher
        )

        return AppContainer(
            environment: environment,
            authRepository: RemoteAuthRepository(apiClient: apiClient, tokenProvider: tokenStore, events: events),
            productRepository: RemoteProductRepository(apiClient: apiClient),
            onboardingRepository: onboardingRepository
        )
    }

    /// Offline container for SwiftUI previews.
    static func preview(isLoggedIn: Bool = true) -> AppContainer {
        AppContainer(
            environment: AppEnvironment(name: "preview", baseURL: URL(string: "https://example.com")!, useMockData: true),
            authRepository: MockAuthRepository(isLoggedIn: isLoggedIn, delay: .milliseconds(300)),
            productRepository: MockProductRepository(delay: .milliseconds(300)),
            onboardingRepository: LocalOnboardingRepository(store: UserDefaultsStore(defaults: UserDefaults(suiteName: "preview")!))
        )
    }

    // MARK: - Factories

    func makeAppRouter() -> AppRouter {
        AppRouter(authRepository: authRepository, onboardingRepository: onboardingRepository)
    }

    func makeOnboardingViewModel(onFinish: @escaping () -> Void) -> OnboardingViewModel {
        OnboardingViewModel(completeOnboarding: CompleteOnboardingUseCase(repository: onboardingRepository), onFinish: onFinish)
    }

    func makeLoginViewModel() -> LoginViewModel {
        let login = LoginUseCase(repository: authRepository)
        #if DEBUG
        // DummyJSON test account, pre-filled to speed up development.
        return LoginViewModel(login: login, username: "emilys", password: "emilyspass")
        #else
        return LoginViewModel(login: login)
        #endif
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(getProducts: GetProductsUseCase(repository: productRepository))
    }

    func makeProductDetailViewModel(id: Product.ID) -> ProductDetailViewModel {
        ProductDetailViewModel(productID: id, getProductDetail: GetProductDetailUseCase(repository: productRepository))
    }

    func makeProfileViewModel() -> ProfileViewModel {
        ProfileViewModel(
            getCurrentUser: GetCurrentUserUseCase(repository: authRepository),
            logout: LogoutUseCase(repository: authRepository),
            environmentName: environment.name,
            appVersion: "\(Bundle.main.appVersion) (\(Bundle.main.buildNumber))"
        )
    }
}
