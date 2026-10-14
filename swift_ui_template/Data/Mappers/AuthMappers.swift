import Foundation

nonisolated extension UserDTO {
    func toDomain() -> User {
        User(
            id: id,
            username: username,
            email: email,
            firstName: firstName,
            lastName: lastName,
            avatarURL: image.flatMap { URL(string: $0) }
        )
    }
}

nonisolated extension AuthResponseDTO {
    var tokens: AuthTokens {
        AuthTokens(accessToken: accessToken, refreshToken: refreshToken)
    }

    func toDomainUser() -> User {
        User(
            id: id,
            username: username,
            email: email,
            firstName: firstName,
            lastName: lastName,
            avatarURL: image.flatMap { URL(string: $0) }
        )
    }
}

nonisolated extension RefreshResponseDTO {
    var tokens: AuthTokens {
        AuthTokens(accessToken: accessToken, refreshToken: refreshToken)
    }
}
