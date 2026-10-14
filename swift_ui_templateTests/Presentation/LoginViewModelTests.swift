import Testing
@testable import swift_ui_template

struct LoginViewModelTests {
    private func makeViewModel(
        repository: MockAuthRepository = MockAuthRepository(delay: .zero),
        username: String = "emilys",
        password: String = "emilyspass"
    ) -> LoginViewModel {
        LoginViewModel(login: LoginUseCase(repository: repository), username: username, password: password)
    }

    @Test func blankUsernameShowsInlineError() async {
        let viewModel = makeViewModel(username: "")

        await viewModel.submit()

        #expect(viewModel.usernameError == DomainError.invalidInput(field: .username, reason: .empty).message)
        #expect(viewModel.passwordError == nil)
        #expect(viewModel.alertMessage == nil)
    }

    @Test func shortPasswordShowsInlineError() async {
        let viewModel = makeViewModel(password: "123")

        await viewModel.submit()

        #expect(viewModel.passwordError == DomainError.invalidInput(field: .password, reason: .tooShort(min: 6)).message)
    }

    @Test func wrongPasswordShowsAlert() async {
        let viewModel = makeViewModel(password: "wrong-password")

        await viewModel.submit()

        #expect(viewModel.alertMessage == DomainError.invalidCredentials.message)
        #expect(viewModel.isShowingAlert)
        #expect(viewModel.isLoading == false)
    }

    @Test func successLogsIn() async {
        let repository = MockAuthRepository(delay: .zero)
        let viewModel = makeViewModel(repository: repository)

        await viewModel.submit()

        #expect(await repository.isLoggedIn())
        #expect(viewModel.alertMessage == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test func dismissingAlertClearsMessage() async {
        let viewModel = makeViewModel(repository: MockAuthRepository(failure: .noConnection, delay: .zero))
        await viewModel.submit()

        viewModel.isShowingAlert = false

        #expect(viewModel.alertMessage == nil)
    }
}
