import Testing
@testable import swift_ui_template

struct AppRouterTests {
    private func makeRouter(seenOnboarding: Bool, auth: MockAuthRepository) -> AppRouter {
        let onboarding = LocalOnboardingRepository(store: UserDefaultsStore(defaults: TestFixtures.makeDefaults()))
        if seenOnboarding { onboarding.markOnboardingSeen() }
        return AppRouter(authRepository: auth, onboardingRepository: onboarding)
    }

    @Test func startsInLaunching() {
        let router = makeRouter(seenOnboarding: false, auth: MockAuthRepository(delay: .zero))

        #expect(router.route == .launching)
    }

    @Test func showsOnboardingFirst() async {
        let router = makeRouter(seenOnboarding: false, auth: MockAuthRepository(isLoggedIn: true, delay: .zero))

        await router.start()

        #expect(router.route == .onboarding)
    }

    @Test func showsMainWhenLoggedIn() async {
        let router = makeRouter(seenOnboarding: true, auth: MockAuthRepository(isLoggedIn: true, delay: .zero))

        await router.start()

        #expect(router.route == .main)
    }

    @Test func showsLoginWhenLoggedOut() async {
        let router = makeRouter(seenOnboarding: true, auth: MockAuthRepository(delay: .zero))

        await router.start()

        #expect(router.route == .login)
    }

    @Test func onboardingFinishedShowsLogin() {
        let router = makeRouter(seenOnboarding: false, auth: MockAuthRepository(delay: .zero))

        router.onboardingFinished()

        #expect(router.route == .login)
    }

    @Test func followsSessionEvents() async throws {
        let auth = MockAuthRepository(delay: .zero)
        let router = makeRouter(seenOnboarding: true, auth: auth)
        await router.start()
        let observation = Task { await router.observeSession() }
        defer { observation.cancel() }

        _ = try await auth.login(username: MockAuthRepository.validUsername, password: MockAuthRepository.validPassword)
        await waitUntil { router.route == .main }
        #expect(router.route == .main)

        auth.expireSession()
        await waitUntil { router.route == .login }
        #expect(router.route == .login)
    }
}
