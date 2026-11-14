import Foundation

/// Search parameters for the Wallpaper Engine Workshop.
struct WorkshopQuery: Equatable {
    static let wallpaperEngineAppID = 431960

    var text = ""
    var sort: WorkshopSort = .trending
    /// Only used by "Most popular".
    var period: WorkshopPeriod = .week
    var filters = WorkshopFilters()
    var pageSize = 30

    func url(apiKey: String, cursor: String) -> URL {
        var components = URLComponents(string: "https://api.steampowered.com/IPublishedFileService/QueryFiles/v1/")!
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let queryType = trimmed.isEmpty ? sort.rawValue : WorkshopSort.textSearch
        var items = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "appid", value: String(Self.wallpaperEngineAppID)),
            URLQueryItem(name: "creator_appid", value: String(Self.wallpaperEngineAppID)),
            URLQueryItem(name: "query_type", value: String(queryType)),
            URLQueryItem(name: "cursor", value: cursor),
            URLQueryItem(name: "numperpage", value: String(pageSize)),
            URLQueryItem(name: "return_tags", value: "true"),
            URLQueryItem(name: "return_previews", value: "true"),
            URLQueryItem(name: "return_short_description", value: "true"),
            URLQueryItem(name: "match_all_tags", value: "true"),
        ]
        if !trimmed.isEmpty {
            items.append(URLQueryItem(name: "search_text", value: trimmed))
        }
        if queryType == WorkshopSort.trending.rawValue, period != .allTime {
            items.append(URLQueryItem(name: "days", value: String(period.rawValue)))
        }
        for (index, tag) in filters.requiredTags.enumerated() {
            items.append(URLQueryItem(name: "requiredtags[\(index)]", value: tag))
        }
        for (index, tag) in filters.excludedTags.enumerated() {
            items.append(URLQueryItem(name: "excludedtags[\(index)]", value: tag))
        }
        components.queryItems = items
        // URLComponents leaves "+" as is, and Steam reads it as a space: cursors like "AoII…H+An" would break paging.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components.url!
    }
}
