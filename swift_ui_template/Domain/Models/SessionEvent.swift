import Foundation

nonisolated enum SessionEvent: Equatable, Sendable {
    case loggedIn
    case loggedOut
    /// The refresh token was rejected; the user must log in again.
    case expired
}
