import Foundation

/// Fixed data for mock repositories and SwiftUI previews.
nonisolated enum SampleData {
    static let user = User(
        id: 1,
        username: "emilys",
        email: "emily.johnson@x.dummyjson.com",
        firstName: "Emily",
        lastName: "Johnson",
        avatarURL: URL(string: "https://dummyjson.com/icon/emilys/128")
    )

    static func products(count: Int) -> [Product] {
        (0..<count).map { offset in
            let index = offset + 1
            return Product(
                id: index,
                title: "Product \(index)",
                description: "Sample description for product \(index).",
                price: Double(index) * 1.5,
                rating: 4.5,
                thumbnailURL: nil,
                imageURLs: [],
                category: "sample",
                brand: "Sample Brand"
            )
        }
    }
}
