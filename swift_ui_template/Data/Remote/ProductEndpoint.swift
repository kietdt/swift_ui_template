import Foundation

nonisolated enum ProductEndpoint: Endpoint {
    case list(skip: Int, limit: Int)
    case detail(id: Int)

    // DummyJSON serves the same data under /auth/... when a valid Bearer token is sent.
    var path: String {
        switch self {
        case .list: "/auth/products"
        case .detail(let id): "/auth/products/\(id)"
        }
    }

    var method: HTTPMethod { .get }

    var query: [URLQueryItem] {
        switch self {
        case .list(let skip, let limit):
            [URLQueryItem(name: "limit", value: String(limit)), URLQueryItem(name: "skip", value: String(skip))]
        case .detail:
            []
        }
    }
}
