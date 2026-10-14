import Testing
@testable import swift_ui_template

struct LoginUseCaseTests {
    private let login = LoginUseCase(repository: MockAuthRepository(delay: .zero))

    @Test func rejectsBlankUsername() async {
        await #expect(throws: DomainError.invalidInput(field: .username, reason: .empty)) {
            try await login(username: "   ", password: "emilyspass")
        }
    }

    @Test func rejectsEmptyPassword() async {
        await #expect(throws: DomainError.invalidInput(field: .password, reason: .empty)) {
            try await login(username: "emilys", password: "")
        }
    }

    @Test func rejectsShortPassword() async {
        await #expect(throws: DomainError.invalidInput(field: .password, reason: .tooShort(min: 6))) {
            try await login(username: "emilys", password: "12345")
        }
    }

    @Test func trimsUsernameBeforeLoggingIn() async throws {
        let user = try await login(username: "  emilys ", password: "emilyspass")

        #expect(user == SampleData.user)
    }
}
