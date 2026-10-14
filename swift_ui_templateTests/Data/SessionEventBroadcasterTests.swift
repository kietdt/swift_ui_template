import Testing
@testable import swift_ui_template

struct SessionEventBroadcasterTests {
    @Test func deliversEventsToEverySubscriber() async {
        let broadcaster = SessionEventBroadcaster()
        let first = broadcaster.stream()
        let second = broadcaster.stream()

        broadcaster.send(.loggedIn)

        var firstIterator = first.makeAsyncIterator()
        var secondIterator = second.makeAsyncIterator()
        #expect(await firstIterator.next() == .loggedIn)
        #expect(await secondIterator.next() == .loggedIn)
    }
}
