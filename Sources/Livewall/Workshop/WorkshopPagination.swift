import Foundation

/// Cursor-backed pages, cached so Previous never needs a network request.
struct WorkshopPagination {
    private struct Entry {
        let cursor: String
        let page: WorkshopPage
    }
    let pageSize: Int
    private var pages: [Entry] = []
    private var index = 0
    private var reachedEnd = false
    private(set) var total: Int?

    init(pageSize: Int = 30) { self.pageSize = max(1, pageSize) }

    var number: Int { index + 1 }
    var items: [WorkshopItem] { pages.indices.contains(index) ? pages[index].page.items : [] }
    var hasPrevious: Bool { index > 0 }
    var hasNext: Bool {
        if index + 1 < pages.count { return true }
        guard !items.isEmpty, !reachedEnd else { return false }
        return total.map { index * pageSize + items.count < $0 } ?? true
    }
    var pageCount: Int? { total.map { $0 > 0 ? ($0 - 1) / pageSize + 1 : 1 } }
    var firstResult: Int { items.isEmpty ? 0 : index * pageSize + 1 }
    var lastResult: Int { items.isEmpty ? 0 : index * pageSize + items.count }

    func cursor(for number: Int) -> String? {
        if number == 1 { return "*" }
        guard number == pages.count + 1, hasNext, let previous = pages.last,
              let next = previous.page.nextCursor, !next.isEmpty, next != previous.cursor else { return nil }
        return next
    }

    @discardableResult
    mutating func showCachedPage(_ number: Int) -> Bool {
        guard pages.indices.contains(number - 1) else { return false }
        index = number - 1
        return true
    }

    mutating func receive(_ page: WorkshopPage, number: Int, cursor: String) {
        guard number == pages.count + 1 else { return }
        total = page.resolvedTotal(previous: total, loadedCount: (number - 1) * pageSize + page.items.count)
        if page.items.isEmpty && !pages.isEmpty {
            reachedEnd = true
            return
        }
        pages.append(Entry(cursor: cursor, page: page))
        index = number - 1
        reachedEnd = page.items.isEmpty || page.nextCursor == nil || page.nextCursor?.isEmpty == true || page.nextCursor == cursor
    }
}
