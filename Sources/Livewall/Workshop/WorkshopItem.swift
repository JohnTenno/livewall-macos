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
    let youTubeVideoID: String?

    var type: WorkshopItemType? { WorkshopItemType(tags: tags) }

    var pageURL: URL { URL(string: "https://steamcommunity.com/sharedfiles/filedetails/?id=\(id)")! }

    /// Resolution inferred from tags (e.g., "3840 x 2160", "2560 x 1440", "1920 x 1080", "4K Ultra HD")
    var resolution: String? {
        for tag in tags {
            if tag.range(of: #"^\d{3,4}\s*[xX×]\s*\d{3,4}$"#, options: .regularExpression) != nil {
                return tag.replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "x", with: " × ")
                    .replacingOccurrences(of: "X", with: " × ")
            }
        }
        for tag in tags {
            let lower = tag.lowercased()
            if lower.contains("4k") || lower.contains("ultra hd") || lower.contains("ultrawide") || lower.contains("2k") || lower.contains("1080p") || lower.contains("720p") {
                return tag
            }
        }
        return nil
    }

    /// Category and genre tags excluding type, resolution, and rating tags.
    var categoryTags: [String] {
        let excluded = Set(WorkshopItemType.allCases.map(\.rawValue) + [
            "Everyone", "Questionable", "Mature", "Unrated",
            "1080p", "2K", "4K", "Ultra HD", "Ultrawide"
        ])
        return tags.filter { tag in
            !excluded.contains(tag) && tag.range(of: #"^\d{3,4}\s*[xX×]\s*\d{3,4}$"#, options: .regularExpression) == nil
        }
    }

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

    private struct PreviewItem: Decodable {
        let previewType: Int?
        let youTubeVideoID: String?

        enum CodingKeys: String, CodingKey {
            case previewType = "preview_type"
            case youTubeVideoID = "youtubevideoid"
        }
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
        let previews = (try? container.decode([PreviewItem].self, forKey: .previews)) ?? []
        youTubeVideoID = previews.first(where: { $0.youTubeVideoID != nil && !$0.youTubeVideoID!.isEmpty })?.youTubeVideoID
    }
}
