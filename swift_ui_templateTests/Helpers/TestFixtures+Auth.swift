import Foundation
@testable import swift_ui_template

nonisolated extension TestFixtures {
    static let tokens = AuthTokens(accessToken: "access-1", refreshToken: "refresh-1")
    static let refreshedTokens = AuthTokens(accessToken: "access-2", refreshToken: "refresh-2")

    static let authResponseJSON = Data("""
    {"id":1,"username":"emilys","email":"emily@example.com","firstName":"Emily","lastName":"Johnson",
     "gender":"female","image":"https://dummyjson.com/icon/emilys/128",
     "accessToken":"access-1","refreshToken":"refresh-1"}
    """.utf8)

    static let userJSON = Data("""
    {"id":1,"username":"emilys","email":"emily@example.com","firstName":"Emily","lastName":"Johnson",
     "image":"https://dummyjson.com/icon/emilys/128","age":28}
    """.utf8)

    static let invalidCredentialsJSON = Data(#"{"message":"Invalid credentials"}"#.utf8)
}
