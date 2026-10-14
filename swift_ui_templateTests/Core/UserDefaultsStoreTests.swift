import Foundation
import Testing
@testable import swift_ui_template

private nonisolated struct Profile: Codable, Equatable, Sendable {
    let name: String
    let age: Int
}

private extension PreferenceKey where Value == Profile {
    static var profile: PreferenceKey<Profile> {
        PreferenceKey(name: "profile", defaultValue: Profile(name: "", age: 0))
    }
}

struct UserDefaultsStoreTests {
    private let store = UserDefaultsStore(defaults: TestFixtures.makeDefaults())

    @Test func returnsDefaultValueWhenUnset() {
        #expect(store.value(for: .hasSeenOnboarding) == false)
    }

    @Test func storesPropertyListValues() {
        store.set(true, for: .hasSeenOnboarding)

        #expect(store.value(for: .hasSeenOnboarding) == true)
    }

    @Test func storesCodableValues() {
        let profile = Profile(name: "Emily", age: 28)

        store.set(profile, for: .profile)

        #expect(store.value(for: .profile) == profile)
    }

    @Test func removeRestoresDefault() {
        store.set(true, for: .hasSeenOnboarding)

        store.remove(.hasSeenOnboarding)

        #expect(store.value(for: .hasSeenOnboarding) == false)
    }
}
