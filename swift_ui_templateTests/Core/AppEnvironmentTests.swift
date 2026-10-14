import Foundation
import Testing
@testable import swift_ui_template

struct AppEnvironmentTests {
    @Test func readsDevValuesFromInfoPlist() {
        let environment = AppEnvironment(bundle: .main, arguments: [])

        #expect(environment.name == "dev")
        #expect(environment.baseURL == URL(string: "https://dummyjson.com"))
        #expect(environment.useMockData == false)
        #expect(environment.isDebug)
    }

    @Test func enablesMockDataFromLaunchArgument() {
        let environment = AppEnvironment(bundle: .main, arguments: ["-UseMockData"])

        #expect(environment.useMockData)
    }
}
