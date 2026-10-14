import Testing
@testable import swift_ui_template

struct TokenStoreTests {
    @Test func isEmptyInitially() async {
        let store = TokenStore(keychain: InMemoryKeychainStore())

        #expect(await store.accessToken() == nil)
        #expect(await store.refreshToken() == nil)
    }

    @Test func savesAndReadsTokens() async {
        let store = TokenStore(keychain: InMemoryKeychainStore())

        await store.save(TestFixtures.tokens)

        #expect(await store.accessToken() == "access-1")
        #expect(await store.refreshToken() == "refresh-1")
    }

    @Test func clearRemovesTokens() async {
        let store = TokenStore(keychain: InMemoryKeychainStore())
        await store.save(TestFixtures.tokens)

        await store.clear()

        #expect(await store.accessToken() == nil)
    }
}
