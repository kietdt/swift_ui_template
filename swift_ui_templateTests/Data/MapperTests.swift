import Foundation
import Testing
@testable import swift_ui_template

struct MapperTests {
    @Test func mapsUser() throws {
        let dto = try JSONDecoder().decode(UserDTO.self, from: TestFixtures.userJSON)

        let user = dto.toDomain()

        #expect(user.id == 1)
        #expect(user.fullName == "Emily Johnson")
        #expect(user.avatarURL == URL(string: "https://dummyjson.com/icon/emilys/128"))
    }

    @Test func mapsAuthResponseToUserAndTokens() throws {
        let dto = try JSONDecoder().decode(AuthResponseDTO.self, from: TestFixtures.authResponseJSON)

        #expect(dto.toDomainUser().username == "emilys")
        #expect(dto.tokens == TestFixtures.tokens)
    }

    @Test func mapsProductPage() throws {
        let json = TestFixtures.productListJSON(skip: 0, limit: 2, total: 5)
        let dto = try JSONDecoder().decode(ProductListDTO.self, from: json)

        let page = dto.toDomain()

        #expect(page.items.map(\.id) == [1, 2])
        #expect(page.items.first?.thumbnailURL == URL(string: "https://cdn.example.com/1.webp"))
        #expect(page.items.first?.brand == nil)
        #expect(page.hasMore)
    }

    @Test(arguments: [
        (APIError.noConnection, DomainError.noConnection),
        (APIError.timeout, DomainError.noConnection),
        (APIError.unauthorized, DomainError.sessionExpired),
        (APIError.decoding("bad"), DomainError.unknown),
        (APIError.http(status: 500, data: Data(#"{"message":"Server down"}"#.utf8)), DomainError.server(message: "Server down")),
        (APIError.http(status: 500, data: Data()), DomainError.server(message: nil)),
    ])
    func mapsAPIErrorToDomainError(apiError: APIError, expected: DomainError) {
        #expect(apiError.toDomainError() == expected)
    }

    @Test func passesCancellationThrough() {
        #expect(mapToDomainError(CancellationError()) is CancellationError)
    }
}
