import Foundation

nonisolated struct LoginRequestDTO: Encodable, Sendable {
    let username: String
    let password: String
    let expiresInMins: Int
}

nonisolated struct AuthResponseDTO: Decodable, Sendable {
    let id: Int
    let username: String
    let email: String
    let firstName: String
    let lastName: String
    let image: String?
    let accessToken: String
    let refreshToken: String
}

nonisolated struct RefreshRequestDTO: Encodable, Sendable {
    let refreshToken: String
    let expiresInMins: Int
}

nonisolated struct RefreshResponseDTO: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
}
