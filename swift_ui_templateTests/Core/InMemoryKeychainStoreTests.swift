import Foundation
import Testing
@testable import swift_ui_template

private nonisolated struct Credentials: Codable, Equatable, Sendable {
    let user: String
    let secret: String
}

struct InMemoryKeychainStoreTests {
    @Test func roundTripsCodableValues() throws {
        let keychain = InMemoryKeychainStore()
        let credentials = Credentials(user: "emilys", secret: "s3cret")

        try keychain.setValue(credentials, for: "credentials")

        #expect(try keychain.value(Credentials.self, for: "credentials") == credentials)
    }

    @Test func missingKeyReturnsNil() throws {
        #expect(try InMemoryKeychainStore().data(for: "missing") == nil)
    }

    @Test func removeDeletesValue() throws {
        let keychain = InMemoryKeychainStore()
        try keychain.set(Data("secret".utf8), for: "key")

        try keychain.remove("key")

        #expect(try keychain.data(for: "key") == nil)
    }
}
