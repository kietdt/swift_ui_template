import Foundation
import Testing
@testable import swift_ui_template

struct NetworkLoggerTests {
    @Test func redactsAuthorizationHeader() {
        var request = URLRequest(url: URL(string: "https://api.example.com")!)
        request.setValue("Bearer secret", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let headers = NetworkLogger.redactedHeaders(of: request)

        #expect(headers["Authorization"] == "<redacted>")
        #expect(headers["Accept"] == "application/json")
    }
}
