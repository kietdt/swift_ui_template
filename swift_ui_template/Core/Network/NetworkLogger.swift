import Foundation
import OSLog

/// Logs requests and responses in DEBUG builds only. Never logs the Authorization header value.
nonisolated struct NetworkLogger: Sendable {
    func log(request: URLRequest, response: HTTPURLResponse?, data: Data, duration: TimeInterval) {
        #if DEBUG
        let status = response.map { String($0.statusCode) } ?? "-"
        let body = String(decoding: data.prefix(1_000), as: UTF8.self)
        AppLogger.network.debug("""
        \(request.httpMethod ?? "-", privacy: .public) \(request.url?.absoluteString ?? "-", privacy: .public) → \(status, privacy: .public) (\(Int(duration * 1_000))ms)
        headers: \(Self.redactedHeaders(of: request), privacy: .public)
        body: \(body, privacy: .public)
        """)
        #endif
    }

    func log(request: URLRequest, error: URLError) {
        #if DEBUG
        AppLogger.network.error("\(request.httpMethod ?? "-", privacy: .public) \(request.url?.absoluteString ?? "-", privacy: .public) failed: \(error.code.rawValue)")
        #endif
    }

    static func redactedHeaders(of request: URLRequest) -> [String: String] {
        var headers = request.allHTTPHeaderFields ?? [:]
        if headers["Authorization"] != nil {
            headers["Authorization"] = "<redacted>"
        }
        return headers
    }
}
