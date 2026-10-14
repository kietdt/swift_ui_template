import Foundation
import OSLog

/// Central `os.Logger` instances. Filter by category in Console.app or the Xcode console.
nonisolated enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "app"

    static let network = Logger(subsystem: subsystem, category: "network")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let storage = Logger(subsystem: subsystem, category: "storage")
}
