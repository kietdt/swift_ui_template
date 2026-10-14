import Foundation

nonisolated protocol AuthRepository: Sendable {
    func login(username: String, password: String) async throws -> User
    func currentUser() async throws -> User
    func logout() async
    func isLoggedIn() async -> Bool
    /// A new stream per call; every subscriber receives every event sent after it subscribed.
    func sessionEvents() -> AsyncStream<SessionEvent>
}
