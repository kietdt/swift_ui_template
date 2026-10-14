import Foundation
import os

/// Fans out `SessionEvent`s to every active `AsyncStream` subscriber.
nonisolated final class SessionEventBroadcaster: Sendable {
    private let continuations = OSAllocatedUnfairLock<[UUID: AsyncStream<SessionEvent>.Continuation]>(initialState: [:])

    /// Subscribes immediately; events sent after this call are buffered until the caller iterates.
    func stream() -> AsyncStream<SessionEvent> {
        let (stream, continuation) = AsyncStream<SessionEvent>.makeStream()
        let id = UUID()
        continuations.withLock { $0[id] = continuation }
        continuation.onTermination = { [weak self] _ in
            self?.continuations.withLock { _ = $0.removeValue(forKey: id) }
        }
        return stream
    }

    func send(_ event: SessionEvent) {
        let subscribers = continuations.withLock { Array($0.values) }
        for continuation in subscribers {
            continuation.yield(event)
        }
    }
}
