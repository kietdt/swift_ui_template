import Foundation
import Testing
@testable import swift_ui_template

struct RemoteAuthRepositoryTests {
    private let tokenStore = TokenStore(keychain: InMemoryKeychainStore())
    private let events = SessionEventBroadcaster()

    private func makeRepository(_ responses: [Result<Data, APIError>]) -> (RemoteAuthRepository, StubAPIClient) {
        let client = StubAPIClient(responses: responses)
        return (RemoteAuthRepository(apiClient: client, tokenProvider: tokenStore, events: events), client)
    }

    @Test func loginStoresTokensAndEmitsLoggedIn() async throws {
        let (repository, client) = makeRepository([.success(TestFixtures.authResponseJSON)])
        var stream = repository.sessionEvents().makeAsyncIterator()

        let user = try await repository.login(username: "emilys", password: "emilyspass")

        #expect(user.username == "emilys")
        #expect(client.requestedPaths == ["/auth/login"])
        #expect(await tokenStore.accessToken() == "access-1")
        #expect(await repository.isLoggedIn())
        #expect(await stream.next() == .loggedIn)
    }

    @Test func loginWithWrongPasswordThrowsInvalidCredentials() async {
        let (repository, _) = makeRepository([.failure(.http(status: 400, data: TestFixtures.invalidCredentialsJSON))])

        await #expect(throws: DomainError.invalidCredentials) {
            try await repository.login(username: "emilys", password: "wrong-password")
        }
        #expect(await repository.isLoggedIn() == false)
    }

    @Test func currentUserMapsUnauthorizedToSessionExpired() async {
        let (repository, _) = makeRepository([.failure(.unauthorized)])

        await #expect(throws: DomainError.sessionExpired) {
            try await repository.currentUser()
        }
    }

    @Test func currentUserCallsMe() async throws {
        let (repository, client) = makeRepository([.success(TestFixtures.userJSON)])

        let user = try await repository.currentUser()

        #expect(user.email == "emily@example.com")
        #expect(client.requestedPaths == ["/auth/me"])
    }

    @Test func logoutClearsTokensAndEmitsLoggedOut() async {
        let (repository, _) = makeRepository([])
        await tokenStore.save(TestFixtures.tokens)
        var stream = repository.sessionEvents().makeAsyncIterator()

        await repository.logout()

        #expect(await repository.isLoggedIn() == false)
        #expect(await stream.next() == .loggedOut)
    }
}
