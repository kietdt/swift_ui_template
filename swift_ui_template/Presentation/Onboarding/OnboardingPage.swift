import Foundation

struct OnboardingPage: Identifiable {
    let id: Int
    let systemImage: String
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource

    static let all: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            systemImage: "sparkles",
            title: "Welcome",
            subtitle: "A clean SwiftUI starting point for your next app."
        ),
        OnboardingPage(
            id: 1,
            systemImage: "network",
            title: "Ready to connect",
            subtitle: "Networking, secure storage and session handling are built in."
        ),
        OnboardingPage(
            id: 2,
            systemImage: "checkmark.seal",
            title: "Built to grow",
            subtitle: "Clear layers make new features easy to add and test."
        ),
    ]
}
