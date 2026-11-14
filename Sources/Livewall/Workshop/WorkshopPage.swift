import Foundation

/// One page of `QueryFiles` results.
struct WorkshopPage: Decodable {
    let total: Int?
    let items: [WorkshopItem]
    let nextCursor: String?

    private struct Envelope: Decodable {
        let response: WorkshopPage
    }

    private enum CodingKeys: String, CodingKey {
        case total
        case items = "publishedfiledetails"
        case nextCursor = "next_cursor"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        total = (try? container.decode(Int.self, forKey: .total))
            ?? (try? container.decode(String.self, forKey: .total)).flatMap(Int.init)
        // Steam omits the array entirely when nothing matches.
        items = try container.decodeIfPresent([WorkshopItem].self, forKey: .items) ?? []
        guard total != nil || container.contains(.items) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                debugDescription: "Steam returned neither search results nor a result count."))
        }
        nextCursor = try? container.decode(String.self, forKey: .nextCursor)
    }

    /// Empty or incomplete later pages must not erase a previously valid count.
    func resolvedTotal(previous: Int?, loadedCount: Int) -> Int? {
        if let total, total >= loadedCount { return total }
        if let previous, previous >= loadedCount { return previous }
        return nil
    }

    static func decode(_ data: Data) throws -> WorkshopPage {
        try JSONDecoder().decode(Envelope.self, from: data).response
    }
}
