import Foundation
import Observation

@Observable
final class ProductDetailViewModel {
    private(set) var state: ViewState<Product> = .idle

    private let productID: Product.ID
    private let getProductDetail: GetProductDetailUseCase

    init(productID: Product.ID, getProductDetail: GetProductDetailUseCase) {
        self.productID = productID
        self.getProductDetail = getProductDetail
    }

    func load() async {
        state = .loading
        do {
            state = .loaded(try await getProductDetail(id: productID))
        } catch is CancellationError {
            // The screen was closed.
        } catch {
            state = .failed(error.userMessage)
        }
    }
}
