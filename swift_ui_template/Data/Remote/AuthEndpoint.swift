import Foundation

nonisolated enum AuthEndpoint: Endpoint {
    /// Lifetime requested for new access tokens.
    static let tokenLifetimeMinutes = 30

    case login(LoginRequestDTO)
    case refresh(RefreshRequestDTO)
    case me

    var path: String {
        switch self {
        case .login: "/auth/login"
        case .refresh: "/auth/refresh"
        case .me: "/auth/me"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .login, .refresh: .post
        case .me: .get
        }
    }

    var body: (any Encodable & Sendable)? {
        switch self {
        case .login(let request): request
        case .refresh(let request): request
        case .me: nil
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .login, .refresh: false
        case .me: true
        }
    }
}
