import Foundation

/// Error body returned by the API, e.g. `{"message":"Invalid credentials"}`.
nonisolated struct ErrorResponseDTO: Decodable, Sendable {
    let message: String
}
