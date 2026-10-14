import Foundation
import os
@testable import swift_ui_template

/// `APIClient` that returns queued responses and records the endpoints it was called with.
nonisolated final class StubAPIClient: APIClient {
    private nonisolated struct State: Sendable {
        var responses: [Result<Data, APIError>]
        var paths: [String] = []
    }

    private let state: OSAllocatedUnfairLock<State>

    init(responses: [Result<Data, APIError>]) {
        state = OSAllocatedUnfairLock(initialState: State(responses: responses))
    }

    var requestedPaths: [String] {
        state.withLock { $0.paths }
    }

    func send<T: Decodable & Sendable>(_ endpoint: some Endpoint) async throws -> T {
        let result = state.withLock { state in
            state.paths.append(endpoint.path)
            return state.responses.removeFirst()
        }
        return try JSONDecoder().decode(T.self, from: result.get())
    }
}
