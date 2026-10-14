import Foundation

nonisolated protocol OnboardingRepository: Sendable {
    func hasSeenOnboarding() -> Bool
    func markOnboardingSeen()
}
