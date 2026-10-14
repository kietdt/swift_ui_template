import Foundation

nonisolated struct GetCurrentUserUseCase: Sendable {
    let repository: any AuthRepository

    func callAsFunction() async throws -> User {
        try await repository.currentUser()
    }
}
