import Testing
@testable import swift_ui_template

struct DomainErrorMessageTests {
    @Test func serverMessageIsShownAsIs() {
        #expect(DomainError.server(message: "Maintenance").message == "Maintenance")
    }

    @Test func nonDomainErrorsUseGenericMessage() {
        struct SomeError: Error {}

        #expect(SomeError().userMessage == DomainError.unknown.message)
    }
}
