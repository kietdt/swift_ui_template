import Testing
@testable import swift_ui_template

struct ProfileViewModelTests {
    private func makeViewModel(_ repository: MockAuthRepository) -> ProfileViewModel {
        ProfileViewModel(
            getCurrentUser: GetCurrentUserUseCase(repository: repository),
            logout: LogoutUseCase(repository: repository),
            environmentName: "dev",
            appVersion: "1.0 (1)"
        )
    }

    @Test func loadShowsCurrentUser() async {
        let viewModel = makeViewModel(MockAuthRepository(isLoggedIn: true, delay: .zero))

        await viewModel.load()

        #expect(viewModel.state == .loaded(SampleData.user))
    }

    @Test func loadFailureShowsMessage() async {
        let viewModel = makeViewModel(MockAuthRepository(isLoggedIn: true, failure: .noConnection, delay: .zero))

        await viewModel.load()

        #expect(viewModel.state == .failed(DomainError.noConnection.message))
    }

    @Test func logoutEndsSession() async {
        let repository = MockAuthRepository(isLoggedIn: true, delay: .zero)
        let viewModel = makeViewModel(repository)

        await viewModel.logout()

        #expect(await repository.isLoggedIn() == false)
    }
}
