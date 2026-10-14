import Testing
@testable import swift_ui_template

struct OnboardingViewModelTests {
    private let repository = LocalOnboardingRepository(store: UserDefaultsStore(defaults: TestFixtures.makeDefaults()))

    @Test func nextAdvancesPage() {
        let viewModel = OnboardingViewModel(completeOnboarding: CompleteOnboardingUseCase(repository: repository), onFinish: {})

        viewModel.next()

        #expect(viewModel.currentIndex == 1)
        #expect(repository.hasSeenOnboarding() == false)
    }

    @Test func nextOnLastPageFinishes() {
        var finished = false
        let viewModel = OnboardingViewModel(completeOnboarding: CompleteOnboardingUseCase(repository: repository), onFinish: { finished = true })
        viewModel.currentIndex = viewModel.pages.count - 1

        viewModel.next()

        #expect(finished)
        #expect(repository.hasSeenOnboarding())
    }

    @Test func skipFinishesImmediately() {
        var finished = false
        let viewModel = OnboardingViewModel(completeOnboarding: CompleteOnboardingUseCase(repository: repository), onFinish: { finished = true })

        viewModel.finish()

        #expect(finished)
        #expect(repository.hasSeenOnboarding())
    }
}
