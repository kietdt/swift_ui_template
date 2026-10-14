import Foundation

nonisolated struct Product: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let description: String
    let price: Double
    let rating: Double
    let thumbnailURL: URL?
    let imageURLs: [URL]
    let category: String
    let brand: String?
}
