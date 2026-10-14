import Foundation
import Observation

@Observable
final class OnboardingViewModel {
    let pages = OnboardingPage.all
    var currentIndex = 0

    var isLastPage: Bool {
        currentIndex == pages.count - 1
    }

    private let completeOnboarding: CompleteOnboardingUseCase
    private let onFinish: () -> Void

    init(completeOnboarding: CompleteOnboardingUseCase, onFinish: @escaping () -> Void) {
        self.completeOnboarding = completeOnboarding
        self.onFinish = onFinish
    }

    func next() {
        if isLastPage {
            finish()
        } else {
            currentIndex += 1
        }
    }

    func finish() {
        completeOnboarding()
        onFinish()
    }
}
