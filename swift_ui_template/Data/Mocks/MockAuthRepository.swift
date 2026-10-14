import Foundation
import os

/// Offline `AuthRepository` for previews, tests and `-UseMockData`.
/// Accepts `emilys` / `emilyspass`, like DummyJSON.
nonisolated final class MockAuthRepository: AuthRepository {
    static let validUsername = "emilys"
    static let validPassword = "emilyspass"

    private let loggedIn: OSAllocatedUnfairLock<Bool>
    private let failure: DomainError?
    private let delay: Duration
    private let events = SessionEventBroadcaster()

    /// - Parameter failure: when set, `login` and `currentUser` always throw it.
    init(isLoggedIn: Bool = false, failure: DomainError? = nil, delay: Duration = .milliseconds(500)) {
        loggedIn = OSAllocatedUnfairLock(initialState: isLoggedIn)
        self.failure = failure
        self.delay = delay
    }

    func login(username: String, password: String) async throws -> User {
        try await Task.sleep(for: delay)
        if let failure { throw failure }
        guard username == Self.validUsername, password == Self.validPassword else {
            throw DomainError.invalidCredentials
        }
        loggedIn.withLock { $0 = true }
        events.send(.loggedIn)
        return SampleData.user
    }

    func currentUser() async throws -> User {
        try await Task.sleep(for: delay)
        if let failure { throw failure }
        return SampleData.user
    }

    func logout() async {
        loggedIn.withLock { $0 = false }
        events.send(.loggedOut)
    }

    func isLoggedIn() async -> Bool {
        loggedIn.withLock { $0 }
    }

    func sessionEvents() -> AsyncStream<SessionEvent> {
        events.stream()
    }

    /// Simulates the API rejecting the refresh token.
    func expireSession() {
        loggedIn.withLock { $0 = false }
        events.send(.expired)
    }
}
