import Foundation
import OSLog

/// Refreshes the access token once, no matter how many requests hit 401 at the same time.
actor TokenRefresher {
    typealias RefreshAction = @Sendable (_ refreshToken: String) async throws -> AuthTokens

    private let tokenProvider: any TokenProvider
    private let refreshAction: RefreshAction
    private let onSessionExpired: @Sendable () async -> Void
    private var inFlight: Task<Void, Error>?

    init(
        tokenProvider: any TokenProvider,
        refreshAction: @escaping RefreshAction,
        onSessionExpired: @escaping @Sendable () async -> Void
    ) {
        self.tokenProvider = tokenProvider
        self.refreshAction = refreshAction
        self.onSessionExpired = onSessionExpired
    }

    /// - Parameter rejectedToken: the access token the server just rejected. If the stored token
    ///   is already different, another request refreshed it and the caller can simply retry.
    func refresh(rejectedToken: String?) async throws {
        if let inFlight { return try await inFlight.value }
        let currentToken = await tokenProvider.accessToken()
        // Re-check after the suspension above: another caller may have started a refresh.
        if let inFlight { return try await inFlight.value }
        if let currentToken, currentToken != rejectedToken { return }

        let task = Task { try await performRefresh() }
        inFlight = task
        defer { inFlight = nil }
        try await task.value
    }

    private func performRefresh() async throws {
        guard let refreshToken = await tokenProvider.refreshToken() else {
            await expireSession()
            throw APIError.unauthorized
        }
        do {
            let tokens = try await refreshAction(refreshToken)
            await tokenProvider.save(tokens)
        } catch {
            AppLogger.auth.error("Token refresh failed: \(String(describing: error), privacy: .public)")
            await expireSession()
            throw APIError.unauthorized
        }
    }

    private func expireSession() async {
        await tokenProvider.clear()
        await onSessionExpired()
    }
}
