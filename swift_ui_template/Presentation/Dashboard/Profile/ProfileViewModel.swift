import Foundation
import Observation

@Observable
final class ProfileViewModel {
    private(set) var state: ViewState<User> = .idle
    var isConfirmingLogout = false
    let environmentName: String
    let appVersion: String

    private let getCurrentUser: GetCurrentUserUseCase
    private let logoutUseCase: LogoutUseCase

    init(getCurrentUser: GetCurrentUserUseCase, logout: LogoutUseCase, environmentName: String, appVersion: String) {
        self.getCurrentUser = getCurrentUser
        logoutUseCase = logout
        self.environmentName = environmentName
        self.appVersion = appVersion
    }

    /// Loads once; switching tabs back does not refetch.
    func load() async {
        guard case .idle = state else { return }
        await fetchUser()
    }

    func retry() async {
        await fetchUser()
    }

    /// `AppRouter` returns to Login when the `.loggedOut` event arrives.
    func logout() async {
        await logoutUseCase()
    }

    private func fetchUser() async {
        state = .loading
        do {
            state = .loaded(try await getCurrentUser())
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(error.userMessage)
        }
    }
}
