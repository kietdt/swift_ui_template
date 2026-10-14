import SwiftUI

struct ProductRow: View {
    let product: Product

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            AsyncImage(url: product.thumbnailURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.15)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.s))

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(product.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(product.price, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

#Preview {
    List(SampleData.products(count: 3)) { ProductRow(product: $0) }
}
