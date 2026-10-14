import Foundation

nonisolated extension ProductDTO {
    func toDomain() -> Product {
        Product(
            id: id,
            title: title,
            description: description,
            price: price,
            rating: rating,
            thumbnailURL: thumbnail.flatMap { URL(string: $0) },
            imageURLs: (images ?? []).compactMap { URL(string: $0) },
            category: category,
            brand: brand
        )
    }
}

nonisolated extension ProductListDTO {
    func toDomain() -> Page<Product> {
        Page(items: products.map { $0.toDomain() }, total: total, skip: skip, limit: limit)
    }
}
