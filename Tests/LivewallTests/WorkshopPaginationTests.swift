import Foundation
import Testing
@testable import Livewall

@Suite struct WorkshopPaginationTests {
    private func page(ids: [String], total: Int? = nil, next: String? = nil) throws -> WorkshopPage {
        var response: [String: Any] = ["publishedfiledetails": ids.map { ["publishedfileid": $0, "title": $0] }]
        if let total { response["total"] = total }
        if let next { response["next_cursor"] = next }
        return try WorkshopPage.decode(JSONSerialization.data(withJSONObject: ["response": response]))
    }

    @Test func nextAndPreviousDisplaySeparateCachedPages() throws {
        var state = WorkshopPagination(pageSize: 2)
        #expect(state.cursor(for: 1) == "*")
        state.receive(try page(ids: ["1", "2"], total: 5, next: "second"), number: 1, cursor: "*")
        #expect(!state.hasPrevious)
        #expect(state.hasNext)
        #expect(state.pageCount == 3)
        #expect(state.cursor(for: 2) == "second")
        state.receive(try page(ids: ["3", "4"], total: 0, next: "third"), number: 2, cursor: "second")
        #expect(state.items.map(\.id) == ["3", "4"])
        #expect(state.firstResult == 3 && state.lastResult == 4)
        #expect(state.total == 5)
        let returnedToFirst = state.showCachedPage(1)
        #expect(returnedToFirst)
        #expect(state.items.map(\.id) == ["1", "2"])
        #expect(state.hasNext)
        let returnedToSecond = state.showCachedPage(2)
        #expect(returnedToSecond)
        state.receive(try page(ids: ["5"], total: 5, next: "unused"), number: 3, cursor: "third")
        #expect(state.number == 3)
        #expect(!state.hasNext)
        let returnedFromLast = state.showCachedPage(1)
        #expect(returnedFromLast)
        #expect(state.hasNext)
        let openedMissingPage = state.showCachedPage(4)
        #expect(!openedMissingPage)
        #expect(state.number == 1)
    }

    @Test func emptyNextPageKeepsTheCurrentResultsAndEndsNavigation() throws {
        var state = WorkshopPagination(pageSize: 2)
        state.receive(try page(ids: ["1", "2"], next: "end"), number: 1, cursor: "*")
        state.receive(try page(ids: [], total: 0), number: 2, cursor: "end")
        #expect(state.number == 1)
        #expect(state.items.count == 2)
        #expect(!state.hasNext)
        #expect(state.total == nil)
    }

    @Test func repeatedCursorsAndEmptySearchesCannotAdvance() throws {
        var repeated = WorkshopPagination()
        repeated.receive(try page(ids: ["1"], next: "*"), number: 1, cursor: "*")
        #expect(!repeated.hasNext)
        var empty = WorkshopPagination()
        empty.receive(try page(ids: [], total: 0), number: 1, cursor: "*")
        #expect(empty.pageCount == 1)
        #expect(!empty.hasNext && !empty.hasPrevious)
    }
}
