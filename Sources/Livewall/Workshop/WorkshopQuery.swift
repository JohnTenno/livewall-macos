import Foundation

/// Search parameters for the Wallpaper Engine Workshop.
struct WorkshopQuery: Equatable {
    static let wallpaperEngineAppID = 431960

    var text = ""
    /// Nil means every type Livewall can play (video or web).
    var type: WorkshopItemType?
    var sort: WorkshopSort = .trending
    var includeMature = false
    var pageSize = 30

    private var requiredTypeTags: [String] {
        if let type { return [type.rawValue] }
        return WorkshopItemType.allCases.filter(\.isSupported).map(\.rawValue)
    }

    /// Wallpaper Engine rating tags.
    private var excludedTags: [String] {
        includeMature ? [] : ["Mature", "Questionable"]
    }

    func url(apiKey: String, cursor: String) -> URL {
        var components = URLComponents(string: "https://api.steampowered.com/IPublishedFileService/QueryFiles/v1/")!
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        var items = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "appid", value: String(Self.wallpaperEngineAppID)),
            URLQueryItem(name: "creator_appid", value: String(Self.wallpaperEngineAppID)),
            URLQueryItem(name: "query_type", value: String(trimmed.isEmpty ? sort.rawValue : WorkshopSort.textSearch)),
            URLQueryItem(name: "cursor", value: cursor),
            URLQueryItem(name: "numperpage", value: String(pageSize)),
            URLQueryItem(name: "return_tags", value: "true"),
            URLQueryItem(name: "return_short_description", value: "true"),
            // A single type must match; several types are alternatives.
            URLQueryItem(name: "match_all_tags", value: "false"),
        ]
        if !trimmed.isEmpty {
            items.append(URLQueryItem(name: "search_text", value: trimmed))
        }
        for (index, tag) in requiredTypeTags.enumerated() {
            items.append(URLQueryItem(name: "requiredtags[\(index)]", value: tag))
        }
        for (index, tag) in excludedTags.enumerated() {
            items.append(URLQueryItem(name: "excludedtags[\(index)]", value: tag))
        }
        components.queryItems = items
        return components.url!
    }
}
