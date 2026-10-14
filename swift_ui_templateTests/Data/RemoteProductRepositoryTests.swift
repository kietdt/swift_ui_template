import Foundation
import os
import Testing
@testable import swift_ui_template

struct RemoteProductRepositoryTests {
    @Test func fetchesAuthenticatedProductPage() async throws {
        let host = TestFixtures.uniqueHost()
        let captured = OSAllocatedUnfairLock<URLRequest?>(initialState: nil)
        let store = TokenStore(keychain: InMemoryKeychainStore())
        await store.save(TestFixtures.tokens)
        let client = URLSessionAPIClient(
            baseURL: URL(string: "https://\(host)")!,
            session: URLProtocolStub.makeSession(host: host) { request in
                captured.withLock { $0 = request }
                return (200, TestFixtures.productListJSON(skip: 20, limit: 20, total: 45))
            },
            tokenProvider: store
        )
        let repository = RemoteProductRepository(apiClient: client)

        let page = try await repository.fetchProducts(skip: 20, limit: 20)

        let request = try #require(captured.withLock { $0 })
        let components = try #require(request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) })
        #expect(components.path == "/auth/products")
        #expect(components.queryItems?.contains(URLQueryItem(name: "limit", value: "20")) == true)
        #expect(components.queryItems?.contains(URLQueryItem(name: "skip", value: "20")) == true)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access-1")
        #expect(page.items.count == 20)
        #expect(page.hasMore)
    }

    @Test func refreshesExpiredTokenThenReturnsProducts() async throws {
        let host = TestFixtures.uniqueHost()
        let store = TokenStore(keychain: InMemoryKeychainStore())
        await store.save(TestFixtures.tokens)
        let refresher = TokenRefresher(tokenProvider: store, refreshAction: { _ in TestFixtures.refreshedTokens }, onSessionExpired: {})
        let client = URLSessionAPIClient(
            baseURL: URL(string: "https://\(host)")!,
            session: URLProtocolStub.makeSession(host: host) { request in
                request.value(forHTTPHeaderField: "Authorization") == "Bearer access-2"
                    ? (200, TestFixtures.productListJSON(skip: 0, limit: 20, total: 45))
                    : (401, Data(#"{"message":"Invalid/Expired Token!"}"#.utf8))
            },
            tokenProvider: store,
            refresher: refresher
        )
        let repository = RemoteProductRepository(apiClient: client)

        let page = try await repository.fetchProducts(skip: 0, limit: 20)

        #expect(page.items.count == 20)
    }

    @Test func fetchProductCallsDetailPath() async throws {
        let client = StubAPIClient(responses: [.success(Data("""
        {"id":3,"title":"Lipstick","description":"Red","price":12.5,"rating":4.1,"category":"beauty","brand":"Brand"}
        """.utf8))])
        let repository = RemoteProductRepository(apiClient: client)

        let product = try await repository.fetchProduct(id: 3)

        #expect(product.title == "Lipstick")
        #expect(product.imageURLs.isEmpty)
        #expect(client.requestedPaths == ["/auth/products/3"])
    }

    @Test func mapsOfflineToDomainError() async {
        let repository = RemoteProductRepository(apiClient: StubAPIClient(responses: [.failure(.noConnection)]))

        await #expect(throws: DomainError.noConnection) {
            try await repository.fetchProducts(skip: 0, limit: 20)
        }
    }
}
