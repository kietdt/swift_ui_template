import Foundation

/// A typed key for `KeyValueStore`. Declare app keys in an extension, for example:
/// `static var hasSeenOnboarding: PreferenceKey<Bool> { .init(name: "hasSeenOnboarding", defaultValue: false) }`
nonisolated struct PreferenceKey<Value: Codable & Sendable>: Sendable {
    let name: String
    let defaultValue: Value
}

nonisolated extension PreferenceKey where Value == Bool {
    static var hasSeenOnboarding: PreferenceKey<Bool> {
        PreferenceKey(name: "hasSeenOnboarding", defaultValue: false)
    }
}
