import Foundation

nonisolated struct GetProductDetailUseCase: Sendable {
    let repository: any ProductRepository

    func callAsFunction(id: Int) async throws -> Product {
        try await repository.fetchProduct(id: id)
    }
}
