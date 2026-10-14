import Testing
@testable import swift_ui_template

struct HomeViewModelTests {
    private func makeViewModel(_ repository: MockProductRepository) -> HomeViewModel {
        HomeViewModel(getProducts: GetProductsUseCase(repository: repository))
    }

    private func items(_ viewModel: HomeViewModel) -> [Product] {
        if case .loaded(let products) = viewModel.state { products } else { [] }
    }

    @Test func loadShowsFirstPage() async {
        let viewModel = makeViewModel(MockProductRepository(delay: .zero))

        await viewModel.load()

        #expect(items(viewModel).count == HomeViewModel.pageSize)
    }

    @Test func loadMoreAppendsUntilLastPage() async throws {
        let repository = MockProductRepository(products: SampleData.products(count: 45), delay: .zero)
        let viewModel = makeViewModel(repository)
        await viewModel.load()

        await viewModel.loadMoreIfNeeded(current: try #require(items(viewModel).last))
        #expect(items(viewModel).count == 40)

        await viewModel.loadMoreIfNeeded(current: try #require(items(viewModel).last))
        #expect(items(viewModel).count == 45)

        await viewModel.loadMoreIfNeeded(current: try #require(items(viewModel).last))
        #expect(items(viewModel).count == 45)
        #expect(repository.fetchProductsCallCount == 3)
    }

    @Test func loadMoreIgnoresRowsOtherThanLast() async throws {
        let repository = MockProductRepository(delay: .zero)
        let viewModel = makeViewModel(repository)
        await viewModel.load()

        await viewModel.loadMoreIfNeeded(current: try #require(items(viewModel).first))

        #expect(repository.fetchProductsCallCount == 1)
    }

    @Test func refreshResetsToFirstPage() async throws {
        let viewModel = makeViewModel(MockProductRepository(delay: .zero))
        await viewModel.load()
        await viewModel.loadMoreIfNeeded(current: try #require(items(viewModel).last))

        await viewModel.refresh()

        #expect(items(viewModel).count == HomeViewModel.pageSize)
    }

    @Test func failureShowsErrorMessage() async {
        let viewModel = makeViewModel(MockProductRepository(failure: .noConnection, delay: .zero))

        await viewModel.load()

        #expect(viewModel.state == .failed(DomainError.noConnection.message))
    }

    @Test func emptyListIsLoadedEmpty() async {
        let viewModel = makeViewModel(MockProductRepository(products: [], delay: .zero))

        await viewModel.load()

        #expect(viewModel.state == .loaded([]))
    }
}
