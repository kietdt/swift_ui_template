import Foundation

nonisolated struct RemoteProductRepository: ProductRepository {
    let apiClient: any APIClient

    func fetchProducts(skip: Int, limit: Int) async throws -> Page<Product> {
        do {
            let response: ProductListDTO = try await apiClient.send(ProductEndpoint.list(skip: skip, limit: limit))
            return response.toDomain()
        } catch {
            throw mapToDomainError(error)
        }
    }

    func fetchProduct(id: Int) async throws -> Product {
        do {
            let response: ProductDTO = try await apiClient.send(ProductEndpoint.detail(id: id))
            return response.toDomain()
        } catch {
            throw mapToDomainError(error)
        }
    }
}
