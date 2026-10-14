import Foundation
import Observation

@Observable
final class LoginViewModel {
    var username: String
    var password: String
    private(set) var usernameError: String?
    private(set) var passwordError: String?
    private(set) var isLoading = false
    var alertMessage: String?

    var isShowingAlert: Bool {
        get { alertMessage != nil }
        set { if !newValue { alertMessage = nil } }
    }

    private let login: LoginUseCase

    init(login: LoginUseCase, username: String = "", password: String = "") {
        self.login = login
        self.username = username
        self.password = password
    }

    /// On success the session emits `.loggedIn` and `AppRouter` switches to the dashboard.
    func submit() async {
        guard !isLoading else { return }
        usernameError = nil
        passwordError = nil
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await login(username: username, password: password)
        } catch DomainError.invalidInput(.username, let reason) {
            usernameError = DomainError.invalidInput(field: .username, reason: reason).message
        } catch DomainError.invalidInput(.password, let reason) {
            passwordError = DomainError.invalidInput(field: .password, reason: reason).message
        } catch is CancellationError {
            // The view went away; nothing to show.
        } catch {
            alertMessage = error.userMessage
        }
    }
}
