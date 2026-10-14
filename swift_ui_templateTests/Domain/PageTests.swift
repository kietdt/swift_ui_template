import Testing
@testable import swift_ui_template

struct PageTests {
    @Test func hasMoreWhileItemsRemain() {
        let page = Page(items: [1, 2], total: 5, skip: 0, limit: 2)

        #expect(page.hasMore)
    }

    @Test func lastPageHasNoMore() {
        let page = Page(items: [41, 42, 43, 44, 45], total: 45, skip: 40, limit: 20)

        #expect(!page.hasMore)
    }
}
