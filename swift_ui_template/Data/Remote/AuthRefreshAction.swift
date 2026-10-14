import Foundation

nonisolated enum AuthRefreshAction {
    /// Builds the closure `TokenRefresher` uses to exchange a refresh token for new tokens.
    /// - Parameter client: a client created **without** a refresher, so a failing refresh never recurses.
    static func make(using client: any APIClient) -> TokenRefresher.RefreshAction {
        { refreshToken in
            let request = RefreshRequestDTO(refreshToken: refreshToken, expiresInMins: AuthEndpoint.tokenLifetimeMinutes)
            let response: RefreshResponseDTO = try await client.send(AuthEndpoint.refresh(request))
            return response.tokens
        }
    }
}
