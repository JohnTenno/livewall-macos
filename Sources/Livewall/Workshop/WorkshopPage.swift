import Foundation

/// One page of `QueryFiles` results.
struct WorkshopPage: Decodable {
    let total: Int
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
        total = (try? container.decode(Int.self, forKey: .total)) ?? 0
        // Steam omits the array entirely when nothing matches.
        items = (try? container.decode([WorkshopItem].self, forKey: .items)) ?? []
        nextCursor = try? container.decode(String.self, forKey: .nextCursor)
    }

    static func decode(_ data: Data) throws -> WorkshopPage {
        try JSONDecoder().decode(Envelope.self, from: data).response
    }
}
