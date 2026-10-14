import Foundation

nonisolated struct LoginUseCase: Sendable {
    static let minPasswordLength = 6

    let repository: any AuthRepository

    func callAsFunction(username: String, password: String) async throws -> User {
        let username = username.trimmed
        guard Validator.isNotBlank(username) else {
            throw DomainError.invalidInput(field: .username, reason: .empty)
        }
        guard Validator.isNotBlank(password) else {
            throw DomainError.invalidInput(field: .password, reason: .empty)
        }
        guard Validator.hasMinLength(password, Self.minPasswordLength) else {
            throw DomainError.invalidInput(field: .password, reason: .tooShort(min: Self.minPasswordLength))
        }
        return try await repository.login(username: username, password: password)
    }
}
