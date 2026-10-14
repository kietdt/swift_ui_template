import Foundation

nonisolated struct ProductDTO: Decodable, Sendable {
    let id: Int
    let title: String
    let description: String
    let price: Double
    let rating: Double
    let thumbnail: String?
    let images: [String]?
    let category: String
    let brand: String?
}

nonisolated struct ProductListDTO: Decodable, Sendable {
    let products: [ProductDTO]
    let total: Int
    let skip: Int
    let limit: Int
}
