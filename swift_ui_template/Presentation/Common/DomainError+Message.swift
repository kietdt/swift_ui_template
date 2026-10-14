import Foundation

extension DomainError {
    /// Localized text shown to the user.
    var message: String {
        switch self {
        case .invalidInput(_, .empty):
            String(localized: "This field is required.")
        case .invalidInput(_, .tooShort(let min)):
            String(localized: "Must be at least \(min) characters.")
        case .invalidCredentials:
            String(localized: "Incorrect username or password.")
        case .sessionExpired:
            String(localized: "Your session has expired. Please log in again.")
        case .noConnection:
            String(localized: "No internet connection. Please try again.")
        case .server(let message?):
            message
        case .server(nil), .unknown:
            String(localized: "Something went wrong. Please try again.")
        }
    }
}

extension Error {
    /// Message for any error reaching the UI; non-domain errors get the generic text.
    var userMessage: String {
        (self as? DomainError ?? .unknown).message
    }
}
