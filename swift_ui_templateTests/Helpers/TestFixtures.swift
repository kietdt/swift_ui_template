import Foundation

/// Shared test data. Feature-specific fixtures live in `TestFixtures+*.swift`.
nonisolated enum TestFixtures {
    /// A fresh, empty `UserDefaults` suite so tests never share state.
    static func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "tests-\(UUID().uuidString)")!
    }

    /// Unique host per call, for `URLProtocolStub`.
    static func uniqueHost() -> String {
        "\(UUID().uuidString.lowercased()).test"
    }
}
