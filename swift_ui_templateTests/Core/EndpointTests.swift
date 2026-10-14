import Foundation
import Testing
@testable import swift_ui_template

private nonisolated struct Body: Codable, Equatable, Sendable {
    let name: String
}

private nonisolated struct TestEndpoint: Endpoint {
    var path = "/items"
    var method = HTTPMethod.get
    var query: [URLQueryItem] = []
    var body: (any Encodable & Sendable)?
    var headers: [String: String] = [:]
}

struct EndpointTests {
    private let baseURL = URL(string: "https://api.example.com")!

    @Test func buildsURLWithPathAndQuery() throws {
        let endpoint = TestEndpoint(query: [URLQueryItem(name: "limit", value: "20")])

        let request = try endpoint.makeRequest(baseURL: baseURL, encoder: JSONEncoder())

        #expect(request.url?.absoluteString == "https://api.example.com/items?limit=20")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test func encodesJSONBody() throws {
        let endpoint = TestEndpoint(method: .post, body: Body(name: "Emily"))

        let request = try endpoint.makeRequest(baseURL: baseURL, encoder: JSONEncoder())

        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(try JSONDecoder().decode(Body.self, from: #require(request.httpBody)) == Body(name: "Emily"))
    }

    @Test func addsCustomHeaders() throws {
        let endpoint = TestEndpoint(headers: ["X-Trace": "abc"])

        let request = try endpoint.makeRequest(baseURL: baseURL, encoder: JSONEncoder())

        #expect(request.value(forHTTPHeaderField: "X-Trace") == "abc")
    }

    @Test func requiresAuthByDefault() {
        #expect(TestEndpoint().requiresAuth)
    }
}
