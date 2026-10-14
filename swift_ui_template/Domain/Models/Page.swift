import Foundation

/// One page of an offset-paginated list.
nonisolated struct Page<Item: Equatable & Sendable>: Equatable, Sendable {
    let items: [Item]
    let total: Int
    let skip: Int
    let limit: Int

    var hasMore: Bool {
        skip + items.count < total
    }
}
