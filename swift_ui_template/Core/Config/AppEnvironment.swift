import Foundation

/// Values that differ per build configuration (Dev / Staging / Prod).
/// They come from `Configs/*.xcconfig` through `Configs/Info.plist`.
nonisolated struct AppEnvironment: Sendable {
    let name: String
    let baseURL: URL
    /// `true` when the app is launched with the `-UseMockData` argument.
    let useMockData: Bool

    static let current = AppEnvironment(bundle: .main, arguments: ProcessInfo.processInfo.arguments)

    var isDebug: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    init(name: String, baseURL: URL, useMockData: Bool) {
        self.name = name
        self.baseURL = baseURL
        self.useMockData = useMockData
    }

    init(bundle: Bundle, arguments: [String]) {
        guard
            let urlString = bundle.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
            let url = URL(string: urlString),
            url.scheme != nil
        else {
            fatalError("API_BASE_URL is missing or invalid. Check Configs/*.xcconfig and Configs/Info.plist.")
        }
        self.init(
            name: bundle.object(forInfoDictionaryKey: "APP_ENVIRONMENT") as? String ?? "unknown",
            baseURL: url,
            useMockData: arguments.contains("-UseMockData")
        )
    }
}
