import Foundation

/// Where `APIClient` and `TokenRefresher` read and write the current tokens.
nonisolated protocol TokenProvider: Sendable {
    func accessToken() async -> String?
    func refreshToken() async -> String?
    func save(_ tokens: AuthTokens) async
    func clear() async
}
