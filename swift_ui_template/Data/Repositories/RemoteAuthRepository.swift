import Foundation
import OSLog

nonisolated struct RemoteAuthRepository: AuthRepository {
    let apiClient: any APIClient
    let tokenProvider: any TokenProvider
    let events: SessionEventBroadcaster

    func login(username: String, password: String) async throws -> User {
        let request = LoginRequestDTO(username: username, password: password, expiresInMins: AuthEndpoint.tokenLifetimeMinutes)
        do {
            let response: AuthResponseDTO = try await apiClient.send(AuthEndpoint.login(request))
            await tokenProvider.save(response.tokens)
            AppLogger.auth.info("Logged in")
            events.send(.loggedIn)
            return response.toDomainUser()
        } catch APIError.http(let status, _) where status == 400 || status == 401 {
            throw DomainError.invalidCredentials
        } catch {
            throw mapToDomainError(error)
        }
    }

    func currentUser() async throws -> User {
        do {
            let user: UserDTO = try await apiClient.send(AuthEndpoint.me)
            return user.toDomain()
        } catch {
            throw mapToDomainError(error)
        }
    }

    func logout() async {
        await tokenProvider.clear()
        AppLogger.auth.info("Logged out")
        events.send(.loggedOut)
    }

    func isLoggedIn() async -> Bool {
        await tokenProvider.accessToken() != nil
    }

    func sessionEvents() -> AsyncStream<SessionEvent> {
        events.stream()
    }
}
