import Testing
@testable import swift_ui_template

struct LocalOnboardingRepositoryTests {
    @Test func remembersOnboardingWasSeen() {
        let repository = LocalOnboardingRepository(store: UserDefaultsStore(defaults: TestFixtures.makeDefaults()))
        #expect(repository.hasSeenOnboarding() == false)

        repository.markOnboardingSeen()

        #expect(repository.hasSeenOnboarding())
    }
}
