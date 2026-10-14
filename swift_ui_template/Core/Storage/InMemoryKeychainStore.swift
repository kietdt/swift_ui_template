import Foundation
import os

/// `KeychainStore` kept in memory. Used by tests, SwiftUI previews and mock mode.
nonisolated final class InMemoryKeychainStore: KeychainStore {
    private let storage: OSAllocatedUnfairLock<[String: Data]>

    init(initial: [String: Data] = [:]) {
        storage = OSAllocatedUnfairLock(initialState: initial)
    }

    func data(for key: String) throws -> Data? {
        storage.withLock { $0[key] }
    }

    func set(_ data: Data, for key: String) throws {
        storage.withLock { $0[key] = data }
    }

    func remove(_ key: String) throws {
        storage.withLock { _ = $0.removeValue(forKey: key) }
    }
}
