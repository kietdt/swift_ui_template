import Foundation
import os
import Testing
@testable import swift_ui_template

struct TokenRefresherTests {
    private func makeStore() async -> TokenStore {
        let store = TokenStore(keychain: InMemoryKeychainStore())
        await store.save(TestFixtures.tokens)
        return store
    }

    @Test func savesRefreshedTokens() async throws {
        let store = await makeStore()
        let refresher = TokenRefresher(
            tokenProvider: store,
            refreshAction: { _ in TestFixtures.refreshedTokens },
            onSessionExpired: {}
        )

        try await refresher.refresh(rejectedToken: "access-1")

        #expect(await store.accessToken() == "access-2")
    }

    @Test func concurrentCallsRefreshOnce() async throws {
        let store = await makeStore()
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let refresher = TokenRefresher(
            tokenProvider: store,
            refreshAction: { _ in
                calls.withLock { $0 += 1 }
                try await Task.sleep(for: .milliseconds(100))
                return TestFixtures.refreshedTokens
            },
            onSessionExpired: {}
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask { try await refresher.refresh(rejectedToken: "access-1") }
            }
            try await group.waitForAll()
        }

        #expect(calls.withLock { $0 } == 1)
    }

    @Test func skipsRefreshWhenTokenAlreadyChanged() async throws {
        let store = await makeStore()
        let calls = OSAllocatedUnfairLock(initialState: 0)
        let refresher = TokenRefresher(
            tokenProvider: store,
            refreshAction: { _ in
                calls.withLock { $0 += 1 }
                return TestFixtures.refreshedTokens
            },
            onSessionExpired: {}
        )

        try await refresher.refresh(rejectedToken: "an-older-token")

        #expect(calls.withLock { $0 } == 0)
    }

    @Test func failedRefreshClearsTokensAndExpiresSession() async {
        let store = await makeStore()
        let expired = OSAllocatedUnfairLock(initialState: false)
        let refresher = TokenRefresher(
            tokenProvider: store,
            refreshAction: { _ in throw APIError.http(status: 403, data: Data()) },
            onSessionExpired: { expired.withLock { $0 = true } }
        )

        await #expect(throws: APIError.unauthorized) {
            try await refresher.refresh(rejectedToken: "access-1")
        }
        #expect(await store.accessToken() == nil)
        #expect(expired.withLock { $0 })
    }
}
