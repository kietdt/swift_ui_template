import Foundation

/// Transport-level errors produced by `APIClient`. The Data layer maps them to `DomainError`.
nonisolated enum APIError: Error, Equatable, Sendable {
    case invalidURL
    case noConnection
    case timeout
    /// The session could not be refreshed; the user must log in again.
    case unauthorized
    case http(status: Int, data: Data)
    case decoding(String)
    case unknown(String)
}
