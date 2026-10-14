import Foundation

nonisolated extension APIError {
    func toDomainError() -> DomainError {
        switch self {
        case .noConnection, .timeout:
            .noConnection
        case .unauthorized:
            .sessionExpired
        case .http(_, let data):
            .server(message: (try? JSONDecoder().decode(ErrorResponseDTO.self, from: data))?.message)
        case .invalidURL, .decoding, .unknown:
            .unknown
        }
    }
}

/// Converts any error thrown below the Domain layer into a `DomainError`.
/// `CancellationError` passes through so callers can ignore cancelled work.
nonisolated func mapToDomainError(_ error: any Error) -> any Error {
    switch error {
    case let apiError as APIError: apiError.toDomainError()
    case is DomainError, is CancellationError: error
    default: DomainError.unknown
    }
}
