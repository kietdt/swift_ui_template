import Foundation
import Testing

struct LocalizationTests {
    private func vietnameseBundle() throws -> Bundle {
        let path = try #require(Bundle.main.path(forResource: "vi", ofType: "lproj"))
        return try #require(Bundle(path: path))
    }

    @Test func appShipsVietnamese() throws {
        let bundle = try vietnameseBundle()

        #expect(bundle.localizedString(forKey: "Log In", value: nil, table: nil) == "Đăng nhập")
    }

    @Test func formatsArguments() throws {
        let bundle = try vietnameseBundle()
        let format = bundle.localizedString(forKey: "Must be at least %lld characters.", value: nil, table: nil)

        #expect(String(format: format, 6) == "Cần ít nhất 6 ký tự.")
    }
}
