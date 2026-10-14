import Foundation

/// Pure input checks shared by use cases and view models.
nonisolated enum Validator {
    static func isNotBlank(_ value: String) -> Bool {
        !value.trimmed.isEmpty
    }

    static func hasMinLength(_ value: String, _ minLength: Int) -> Bool {
        value.count >= minLength
    }

    static func isValidEmail(_ value: String) -> Bool {
        value.wholeMatch(of: /[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/) != nil
    }
}
