import Foundation

/// Secure storage for secrets such as auth tokens.
nonisolated protocol KeychainStore: Sendable {
    func data(for key: String) throws -> Data?
    func set(_ data: Data, for key: String) throws
    func remove(_ key: String) throws
}

nonisolated extension KeychainStore {
    func value<Value: Decodable>(_ type: Value.Type, for key: String) throws -> Value? {
        guard let data = try data(for: key) else { return nil }
        return try JSONDecoder().decode(Value.self, from: data)
    }

    func setValue<Value: Encodable>(_ value: Value, for key: String) throws {
        try set(JSONEncoder().encode(value), for: key)
    }
}

nonisolated enum KeychainError: Error, Equatable {
    case unhandled(OSStatus)
}
