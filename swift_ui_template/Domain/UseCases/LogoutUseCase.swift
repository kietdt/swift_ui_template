import Foundation

nonisolated struct LogoutUseCase: Sendable {
    let repository: any AuthRepository

    func callAsFunction() async {
        await repository.logout()
    }
}
