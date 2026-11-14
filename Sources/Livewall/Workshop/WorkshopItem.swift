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
    let previews: [WorkshopPreview]

    var youtubePreviewID: String? { previews.compactMap(\.youtubeVideoID).first }

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
        case previews
    }

    private struct Tag: Decodable {
        let tag: String
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled"
        previewURL = try? container.decodeIfPresent(URL.self, forKey: .previewURL)
        // Steam encodes 64-bit numbers as strings.
        fileSize = (try? container.decode(String.self, forKey: .fileSize)).flatMap(UInt64.init)
            ?? (try? container.decode(UInt64.self, forKey: .fileSize)) ?? 0
        subscriptions = (try? container.decode(Int.self, forKey: .subscriptions)) ?? 0
        tags = ((try? container.decode([Tag].self, forKey: .tags)) ?? []).map(\.tag)
        shortDescription = (try? container.decode(String.self, forKey: .shortDescription)) ?? ""
        previews = (try? container.decode([WorkshopPreview].self, forKey: .previews)) ?? []
    }
}

/// Steam additional preview type 1 contains a YouTube video identifier.
struct WorkshopPreview: Decodable, Hashable {
    let type: Int
    let reference: String

    var youtubeVideoID: String? {
        guard type == 1, reference.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil else { return nil }
        return reference
    }

    private enum CodingKeys: String, CodingKey {
        case type = "preview_type"
        case externalReference = "external_reference"
        case youtubeID = "youtubevideoid"
        case url
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        type = (try? values.decode(Int.self, forKey: .type))
            ?? (try? values.decode(String.self, forKey: .type)).flatMap(Int.init) ?? -1
        reference = [CodingKeys.youtubeID, .externalReference, .url]
            .compactMap { try? values.decode(String.self, forKey: $0) }
            .first(where: { !$0.isEmpty }) ?? ""
    }
}
