import SwiftUI

struct ProductDetailView: View {
    @State var viewModel: ProductDetailViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                LoadingView()
            case .failed(let message):
                ErrorStateView(message: message) {
                    Task { await viewModel.load() }
                }
            case .loaded(let product):
                details(of: product)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private func details(of product: Product) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                if !product.imageURLs.isEmpty {
                    TabView {
                        ForEach(product.imageURLs, id: \.self) { url in
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                ProgressView()
                            }
                        }
                    }
                    .tabViewStyle(.page)
                    .frame(height: 300)
                }

                Text(product.title)
                    .font(.title2.bold())
                if let brand = product.brand {
                    Text(brand)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(product.price, format: .currency(code: "USD"))
                        .font(.title3.bold())
                    Spacer()
                    Label(product.rating.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                        .foregroundStyle(.orange)
                }
                Text(product.description)
            }
            .padding(Theme.Spacing.m)
        }
        .navigationTitle(product.title)
    }
}

#Preview {
    NavigationStack {
        ProductDetailView(viewModel: AppContainer.preview().makeProductDetailViewModel(id: 1))
    }
}
