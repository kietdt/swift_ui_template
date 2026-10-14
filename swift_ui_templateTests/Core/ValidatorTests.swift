import Testing
@testable import swift_ui_template

struct ValidatorTests {
    @Test(arguments: ["", "   ", "\n"])
    func blankStringsAreRejected(value: String) {
        #expect(!Validator.isNotBlank(value))
    }

    @Test func nonBlankStringIsAccepted() {
        #expect(Validator.isNotBlank(" emilys "))
    }

    @Test func minLength() {
        #expect(Validator.hasMinLength("123456", 6))
        #expect(!Validator.hasMinLength("12345", 6))
    }

    @Test func email() {
        #expect(Validator.isValidEmail("emily@example.com"))
        #expect(!Validator.isValidEmail("emily@"))
        #expect(!Validator.isValidEmail("not an email"))
    }
}
