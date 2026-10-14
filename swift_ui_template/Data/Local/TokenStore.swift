import Foundation
import OSLog

/// Persists `AuthTokens` in the Keychain. The actor serialises reads and writes.
actor TokenStore: TokenProvider {
    private static let key = "auth.tokens"

    private let keychain: any KeychainStore

    init(keychain: any KeychainStore) {
        self.keychain = keychain
    }

    func accessToken() -> String? {
        load()?.accessToken
    }

    func refreshToken() -> String? {
        load()?.refreshToken
    }

    func save(_ tokens: AuthTokens) {
        do {
            try keychain.setValue(tokens, for: Self.key)
        } catch {
            AppLogger.storage.error("Saving tokens failed: \(String(describing: error), privacy: .public)")
        }
    }

    func clear() {
        do {
            try keychain.remove(Self.key)
        } catch {
            AppLogger.storage.error("Clearing tokens failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func load() -> AuthTokens? {
        do {
            return try keychain.value(AuthTokens.self, for: Self.key)
        } catch {
            AppLogger.storage.error("Reading tokens failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
