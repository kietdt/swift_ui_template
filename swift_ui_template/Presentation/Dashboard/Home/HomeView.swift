import SwiftUI

struct HomeView: View {
    @Environment(AppContainer.self) private var container
    @State var viewModel: HomeViewModel

    var body: some View {
        content
            .navigationTitle("Home")
            .navigationDestination(for: Product.ID.self) { id in
                ProductDetailView(viewModel: container.makeProductDetailViewModel(id: id))
            }
            .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView()
        case .failed(let message):
            ErrorStateView(message: message) {
                Task { await viewModel.retry() }
            }
        case .loaded(let products) where products.isEmpty:
            EmptyStateView(message: "No products yet")
        case .loaded(let products):
            List {
                ForEach(products) { product in
                    NavigationLink(value: product.id) {
                        ProductRow(product: product)
                    }
                    .onAppear {
                        Task { await viewModel.loadMoreIfNeeded(current: product) }
                    }
                }
                if viewModel.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
            .listStyle(.plain)
            .refreshable { await viewModel.refresh() }
        }
    }
}

#Preview {
    let container = AppContainer.preview()
    NavigationStack {
        HomeView(viewModel: container.makeHomeViewModel())
    }
    .environment(container)
}
