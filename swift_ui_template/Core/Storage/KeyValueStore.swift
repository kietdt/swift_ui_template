import Foundation

/// Non-sensitive key/value storage (feature flags, "seen" markers, user settings).
/// Never store tokens or passwords here — use `KeychainStore`.
nonisolated protocol KeyValueStore: Sendable {
    func value<Value>(for key: PreferenceKey<Value>) -> Value
    func set<Value>(_ value: Value, for key: PreferenceKey<Value>)
    func remove<Value>(_ key: PreferenceKey<Value>)
}
