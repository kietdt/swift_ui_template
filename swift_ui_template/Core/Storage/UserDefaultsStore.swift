import Foundation
import OSLog

/// `KeyValueStore` backed by `UserDefaults`.
/// Property-list types are stored as-is; other `Codable` values are stored as JSON `Data`.
nonisolated final class UserDefaultsStore: KeyValueStore, @unchecked Sendable {
    // UserDefaults is thread-safe; @unchecked is needed because it is not marked Sendable.
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func value<Value>(for key: PreferenceKey<Value>) -> Value {
        guard let object = defaults.object(forKey: key.name) else { return key.defaultValue }
        if let value = object as? Value { return value }
        if let data = object as? Data, let value = try? JSONDecoder().decode(Value.self, from: data) {
            return value
        }
        return key.defaultValue
    }

    func set<Value>(_ value: Value, for key: PreferenceKey<Value>) {
        if Self.isPropertyListValue(value) {
            defaults.set(value, forKey: key.name)
        } else if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key.name)
        } else {
            AppLogger.storage.error("Failed to encode value for key \(key.name, privacy: .public)")
        }
    }

    func remove<Value>(_ key: PreferenceKey<Value>) {
        defaults.removeObject(forKey: key.name)
    }

    private static func isPropertyListValue(_ value: Any) -> Bool {
        value is Bool || value is Int || value is Double || value is String || value is Data || value is Date
    }
}
