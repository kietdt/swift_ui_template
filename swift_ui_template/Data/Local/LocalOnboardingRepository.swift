import Foundation

nonisolated struct LocalOnboardingRepository: OnboardingRepository {
    let store: any KeyValueStore

    func hasSeenOnboarding() -> Bool {
        store.value(for: .hasSeenOnboarding)
    }

    func markOnboardingSeen() {
        store.set(true, for: .hasSeenOnboarding)
    }
}
