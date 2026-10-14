import Foundation

nonisolated final class URLSessionAPIClient: APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: any TokenProvider
    private let refresher: TokenRefresher?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let logger: NetworkLogger

    /// - Parameter refresher: pass `nil` for a client that must never refresh (e.g. the one that
    ///   performs the refresh call itself).
    init(
        baseURL: URL,
        session: URLSession = .shared,
        tokenProvider: any TokenProvider,
        refresher: TokenRefresher? = nil,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        logger: NetworkLogger = NetworkLogger()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
        self.refresher = refresher
        self.encoder = encoder
        self.decoder = decoder
        self.logger = logger
    }

    func send<T: Decodable & Sendable>(_ endpoint: some Endpoint) async throws -> T {
        let data = try await perform(endpoint, allowRefresh: true)
        return try await Self.decode(T.self, from: data, using: decoder)
    }

    private func perform(_ endpoint: some Endpoint, allowRefresh: Bool) async throws -> Data {
        var request = try endpoint.makeRequest(baseURL: baseURL, encoder: encoder)
        var attachedToken: String?
        if endpoint.requiresAuth, let token = await tokenProvider.accessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            attachedToken = token
        }

        let (data, response) = try await load(request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        switch status {
        case 200..<300:
            return data
        case 401 where endpoint.requiresAuth:
            guard allowRefresh, let refresher else { throw APIError.unauthorized }
            try await refresher.refresh(rejectedToken: attachedToken)
            return try await perform(endpoint, allowRefresh: false)
        default:
            throw APIError.http(status: status, data: data)
        }
    }

    private func load(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let start = Date()
        do {
            let (data, response) = try await session.data(for: request)
            logger.log(request: request, response: response as? HTTPURLResponse, data: data, duration: Date().timeIntervalSince(start))
            return (data, response)
        } catch let error as URLError {
            logger.log(request: request, error: error)
            switch error.code {
            case .cancelled: throw CancellationError()
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed: throw APIError.noConnection
            case .timedOut: throw APIError.timeout
            default: throw APIError.unknown(error.localizedDescription)
            }
        }
    }

    /// Decodes off the main actor so large payloads never block the UI.
    @concurrent
    private static func decode<T: Decodable & Sendable>(_ type: T.Type, from data: Data, using decoder: JSONDecoder) async throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }
}
