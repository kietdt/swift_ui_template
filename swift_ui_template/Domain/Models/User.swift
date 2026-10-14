import Foundation

nonisolated struct User: Identifiable, Equatable, Sendable {
    let id: Int
    let username: String
    let email: String
    let firstName: String
    let lastName: String
    let avatarURL: URL?

    var fullName: String {
        "\(firstName) \(lastName)"
    }
}
