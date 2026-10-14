import Foundation
import Observation

enum AppRoute: Equatable {
    /// Shown for a moment while `start()` reads the stored session.
    case launching
    case onboarding
    case login
    case main
}

/// Decides which top-level flow is on screen.
@Observable
final class AppRouter {
    private(set) var route: AppRoute = .launching

    private let authRepository: any AuthRepository
    private let onboardingRepository: any OnboardingRepository
    // Subscribed in init so no event is missed before `observeSession()` starts iterating.
    private let sessionEvents: AsyncStream<SessionEvent>

    init(authRepository: any AuthRepository, onboardingRepository: any OnboardingRepository) {
        self.authRepository = authRepository
        self.onboardingRepository = onboardingRepository
        sessionEvents = authRepository.sessionEvents()
    }

    func start() async {
        if !onboardingRepository.hasSeenOnboarding() {
            route = .onboarding
        } else if await authRepository.isLoggedIn() {
            route = .main
        } else {
            route = .login
        }
    }

    /// Runs until the calling task is cancelled.
    func observeSession() async {
        for await event in sessionEvents {
            switch event {
            case .loggedIn: route = .main
            case .loggedOut, .expired: route = .login
            }
        }
    }

    func onboardingFinished() {
        route = .login
    }
}
