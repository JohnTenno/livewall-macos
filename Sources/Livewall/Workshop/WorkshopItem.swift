import Foundation

/// A Workshop entry as returned by `IPublishedFileService/QueryFiles`.
struct WorkshopItem: Identifiable, Decodable, Hashable {
    let id: String
    let title: String
    let previewURL: URL?
    let fileSize: UInt64
    let subscriptions: Int
    let tags: [String]
    let shortDescription: String

    var type: WorkshopItemType? { WorkshopItemType(tags: tags) }

    var pageURL: URL { URL(string: "https://steamcommunity.com/sharedfiles/filedetails/?id=\(id)")! }

    private enum CodingKeys: String, CodingKey {
        case id = "publishedfileid"
        case title
        case previewURL = "preview_url"
        case fileSize = "file_size"
        case subscriptions
        case tags
        case shortDescription = "short_description"
    }

    private struct Tag: Decodable {
        let tag: String
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Sin título"
        previewURL = try? container.decodeIfPresent(URL.self, forKey: .previewURL)
        // Steam encodes 64-bit numbers as strings.
        fileSize = (try? container.decode(String.self, forKey: .fileSize)).flatMap(UInt64.init)
            ?? (try? container.decode(UInt64.self, forKey: .fileSize)) ?? 0
        subscriptions = (try? container.decode(Int.self, forKey: .subscriptions)) ?? 0
        tags = ((try? container.decode([Tag].self, forKey: .tags)) ?? []).map(\.tag)
        shortDescription = (try? container.decode(String.self, forKey: .shortDescription)) ?? ""
    }
}
