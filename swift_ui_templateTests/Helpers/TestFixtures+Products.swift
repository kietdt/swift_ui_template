import Foundation

nonisolated extension TestFixtures {
    /// A DummyJSON-shaped product page; product ids are 1-based positions.
    static func productListJSON(skip: Int, limit: Int, total: Int) -> Data {
        let end = min(skip + limit, total)
        let products = (skip < end ? Array(skip..<end) : []).map { index in
            """
            {"id":\(index + 1),"title":"Product \(index + 1)","description":"Description","price":9.99,
             "rating":4.5,"thumbnail":"https://cdn.example.com/\(index + 1).webp","images":[],"category":"beauty"}
            """
        }
        return Data(#"{"products":[\#(products.joined(separator: ","))],"total":\#(total),"skip":\#(skip),"limit":\#(limit)}"#.utf8)
    }
}
