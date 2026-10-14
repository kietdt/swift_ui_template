import Foundation
import os

/// Offline `ProductRepository` that paginates over an in-memory array.
nonisolated final class MockProductRepository: ProductRepository {
    private let products: [Product]
    private let failure: DomainError?
    private let delay: Duration
    private let fetchCount = OSAllocatedUnfairLock(initialState: 0)

    /// Number of `fetchProducts` calls so far (handy in tests).
    var fetchProductsCallCount: Int {
        fetchCount.withLock { $0 }
    }

    init(products: [Product] = SampleData.products(count: 45), failure: DomainError? = nil, delay: Duration = .milliseconds(500)) {
        self.products = products
        self.failure = failure
        self.delay = delay
    }

    func fetchProducts(skip: Int, limit: Int) async throws -> Page<Product> {
        fetchCount.withLock { $0 += 1 }
        try await Task.sleep(for: delay)
        if let failure { throw failure }
        let end = min(skip + limit, products.count)
        let items = skip < end ? Array(products[skip..<end]) : []
        return Page(items: items, total: products.count, skip: skip, limit: limit)
    }

    func fetchProduct(id: Int) async throws -> Product {
        try await Task.sleep(for: delay)
        if let failure { throw failure }
        guard let product = products.first(where: { $0.id == id }) else {
            throw DomainError.server(message: "Product not found")
        }
        return product
    }
}
