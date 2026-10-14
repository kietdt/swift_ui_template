import Foundation

nonisolated struct UserDTO: Decodable, Sendable {
    let id: Int
    let username: String
    let email: String
    let firstName: String
    let lastName: String
    let image: String?
}
