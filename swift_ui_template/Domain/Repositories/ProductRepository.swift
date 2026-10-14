import Foundation

nonisolated protocol ProductRepository: Sendable {
    func fetchProducts(skip: Int, limit: Int) async throws -> Page<Product>
    func fetchProduct(id: Int) async throws -> Product
}
