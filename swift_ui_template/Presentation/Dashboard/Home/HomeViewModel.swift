import Foundation
import Observation
import OSLog

@Observable
final class HomeViewModel {
    static let pageSize = 20

    private(set) var state: ViewState<[Product]> = .idle
    private(set) var isLoadingMore = false

    private var lastPage: Page<Product>?
    private let getProducts: GetProductsUseCase

    init(getProducts: GetProductsUseCase) {
        self.getProducts = getProducts
    }

    /// First load only; does nothing once data has been requested.
    func load() async {
        guard case .idle = state else { return }
        state = .loading
        await loadFirstPage()
    }

    func refresh() async {
        await loadFirstPage()
    }

    func retry() async {
        state = .loading
        await loadFirstPage()
    }

    /// Call when `product` appears on screen; fetches the next page when it is the last row.
    func loadMoreIfNeeded(current product: Product) async {
        guard
            case .loaded(let products) = state,
            product.id == products.last?.id,
            lastPage?.hasMore == true,
            !isLoadingMore
        else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await getProducts(skip: products.count, limit: Self.pageSize)
            lastPage = page
            state = .loaded(products + page.items)
        } catch {
            // Keep the rows already shown; the next scroll to the bottom retries.
            AppLogger.network.error("Loading more products failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func loadFirstPage() async {
        do {
            let page = try await getProducts(skip: 0, limit: Self.pageSize)
            lastPage = page
            state = .loaded(page.items)
        } catch is CancellationError {
            // Pull-to-refresh was cancelled; keep the current state.
        } catch {
            state = .failed(error.userMessage)
        }
    }
}
