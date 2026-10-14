import Foundation

nonisolated struct CompleteOnboardingUseCase: Sendable {
    let repository: any OnboardingRepository

    func callAsFunction() {
        repository.markOnboardingSeen()
    }
}
