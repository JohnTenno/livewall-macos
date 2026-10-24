import Foundation

/// Subset of Steam's `EPublishedFileQueryType`.
enum WorkshopSort: Int, CaseIterable, Identifiable {
    case trending = 3
    case mostSubscribed = 9
    case newest = 1
    case topRated = 0

    /// Used automatically whenever there is search text.
    static let textSearch = 12

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .trending: "Trending"
        case .mostSubscribed: "Most subscribed"
        case .newest: "Newest"
        case .topRated: "Top rated"
        }
    }
}
