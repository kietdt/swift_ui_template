import Foundation

/// Polls `condition` until it is true or `timeout` passes. Use for state changed by another task.
func waitUntil(timeout: Duration = .seconds(1), _ condition: () -> Bool) async {
    let deadline = ContinuousClock.now + timeout
    while !condition(), ContinuousClock.now < deadline {
        try? await Task.sleep(for: .milliseconds(5))
    }
}
