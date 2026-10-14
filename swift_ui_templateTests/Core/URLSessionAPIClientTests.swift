import Foundation
import os
import Testing
@testable import swift_ui_template

private nonisolated struct Item: Decodable, Equatable, Sendable {
    let id: Int
}

private nonisolated enum TestEndpoint: Endpoint {
    case secured
    case open

    var path: String { "/item" }
    var method: HTTPMethod { .get }
    var requiresAuth: Bool { self == .secured }
}

struct URLSessionAPIClientTests {
    private let host = TestFixtures.uniqueHost()

    private func makeClient(
        tokens: AuthTokens? = TestFixtures.tokens,
        refresher: (TokenStore) -> TokenRefresher? = { _ in nil },
        handler: @escaping URLProtocolStub.Handler
    ) async -> (URLSessionAPIClient, TokenStore) {
        let store = TokenStore(keychain: InMemoryKeychainStore())
        if let tokens { await store.save(tokens) }
        let client = URLSessionAPIClient(
            baseURL: URL(string: "https://\(host)")!,
            session: URLProtocolStub.makeSession(host: host, handler: handler),
            tokenProvider: store,
            refresher: refresher(store)
        )
        return (client, store)
    }

    @Test func decodesSuccessfulResponse() async throws {
        let (client, _) = await makeClient { _ in (200, Data(#"{"id":7}"#.utf8)) }

        let item: Item = try await client.send(TestEndpoint.secured)

        #expect(item == Item(id: 7))
    }

    @Test func attachesBearerTokenWhenRequired() async throws {
        let header = OSAllocatedUnfairLock<String?>(initialState: nil)
        let (client, _) = await makeClient { request in
            header.withLock { $0 = request.value(forHTTPHeaderField: "Authorization") }
            return (200, Data(#"{"id":1}"#.utf8))
        }

        let _: Item = try await client.send(TestEndpoint.secured)

        #expect(header.withLock { $0 } == "Bearer access-1")
    }

    @Test func omitsBearerTokenForOpenEndpoints() async throws {
        let header = OSAllocatedUnfairLock<String?>(initialState: "unset")
        let (client, _) = await makeClient { request in
            header.withLock { $0 = request.value(forHTTPHeaderField: "Authorization") }
            return (200, Data(#"{"id":1}"#.utf8))
        }

        let _: Item = try await client.send(TestEndpoint.open)

        #expect(header.withLock { $0 } == nil)
    }

    @Test func mapsErrorStatusToHTTPError() async {
        let body = Data(#"{"message":"boom"}"#.utf8)
        let (client, _) = await makeClient { _ in (500, body) }

        await #expect(throws: APIError.http(status: 500, data: body)) {
            let _: Item = try await client.send(TestEndpoint.secured)
        }
    }

    @Test func mapsOfflineToNoConnection() async {
        let (client, _) = await makeClient { _ in throw URLError(.notConnectedToInternet) }

        await #expect(throws: APIError.noConnection) {
            let _: Item = try await client.send(TestEndpoint.secured)
        }
    }

    @Test func mapsInvalidJSONToDecodingError() async {
        let (client, _) = await makeClient { _ in (200, Data("not json".utf8)) }

        await #expect {
            let _: Item = try await client.send(TestEndpoint.secured)
        } throws: { error in
            if case APIError.decoding = error { true } else { false }
        }
    }

    @Test func refreshesAndRetriesOnUnauthorized() async throws {
        let (client, store) = await makeClient(
            refresher: { store in
                TokenRefresher(tokenProvider: store, refreshAction: { _ in TestFixtures.refreshedTokens }, onSessionExpired: {})
            },
            handler: { request in
                request.value(forHTTPHeaderField: "Authorization") == "Bearer access-2"
                    ? (200, Data(#"{"id":1}"#.utf8))
                    : (401, Data())
            }
        )

        let item: Item = try await client.send(TestEndpoint.secured)

        #expect(item == Item(id: 1))
        #expect(await store.accessToken() == "access-2")
    }

    @Test func failedRefreshThrowsUnauthorizedAndExpiresSession() async {
        let expired = OSAllocatedUnfairLock(initialState: false)
        let (client, store) = await makeClient(
            refresher: { store in
                TokenRefresher(
                    tokenProvider: store,
                    refreshAction: { _ in throw APIError.http(status: 403, data: Data()) },
                    onSessionExpired: { expired.withLock { $0 = true } }
                )
            },
            handler: { _ in (401, Data()) }
        )

        await #expect(throws: APIError.unauthorized) {
            let _: Item = try await client.send(TestEndpoint.secured)
        }
        #expect(await store.accessToken() == nil)
        #expect(expired.withLock { $0 })
    }

    @Test func unauthorizedWithoutRefresherThrowsUnauthorized() async {
        let (client, _) = await makeClient { _ in (401, Data()) }

        await #expect(throws: APIError.unauthorized) {
            let _: Item = try await client.send(TestEndpoint.secured)
        }
    }
}
