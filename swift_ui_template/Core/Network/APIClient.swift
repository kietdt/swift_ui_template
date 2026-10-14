import Foundation

nonisolated protocol APIClient: Sendable {
    /// Sends the request and decodes the JSON response body into `T`.
    /// - Throws: `APIError`, or `CancellationError` when the task is cancelled.
    func send<T: Decodable & Sendable>(_ endpoint: some Endpoint) async throws -> T
}
