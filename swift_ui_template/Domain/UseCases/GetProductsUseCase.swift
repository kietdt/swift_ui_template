import Foundation

nonisolated struct GetProductsUseCase: Sendable {
    let repository: any ProductRepository

    func callAsFunction(skip: Int, limit: Int) async throws -> Page<Product> {
        try await repository.fetchProducts(skip: skip, limit: limit)
    }
}
