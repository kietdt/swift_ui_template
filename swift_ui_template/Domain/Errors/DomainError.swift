import Foundation

/// The only error type the Presentation layer handles.
nonisolated enum DomainError: Error, Equatable, Sendable {
    enum InputField: Equatable, Sendable {
        case username
        case password
    }

    enum InputReason: Equatable, Sendable {
        case empty
        case tooShort(min: Int)
    }

    case invalidInput(field: InputField, reason: InputReason)
    case invalidCredentials
    case sessionExpired
    case noConnection
    case server(message: String?)
    case unknown
}
