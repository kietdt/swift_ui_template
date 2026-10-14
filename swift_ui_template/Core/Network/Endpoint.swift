import Foundation

/// Describes one API call. Each feature declares its endpoints as an enum conforming to this protocol.
nonisolated protocol Endpoint: Sendable {
    var path: String { get }
    var method: HTTPMethod { get }
    var query: [URLQueryItem] { get }
    var body: (any Encodable & Sendable)? { get }
    var headers: [String: String] { get }
    /// When `true`, `APIClient` attaches the access token and refreshes it on 401.
    var requiresAuth: Bool { get }
}

nonisolated extension Endpoint {
    var query: [URLQueryItem] { [] }
    var body: (any Encodable & Sendable)? { nil }
    var headers: [String: String] { [:] }
    var requiresAuth: Bool { true }

    func makeRequest(baseURL: URL, encoder: JSONEncoder) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }
}
