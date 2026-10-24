import Foundation

/// Wallpaper Engine's item types, exposed on the Workshop as tags.
enum WorkshopItemType: String, CaseIterable, Identifiable {
    case video = "Video"
    case web = "Web"
    case scene = "Scene"
    case application = "Application"

    var id: String { rawValue }

    /// Only video and web items can be rendered by Livewall; scenes use Wallpaper Engine's proprietary engine.
    var isSupported: Bool { self == .video || self == .web }

    var displayName: String {
        switch self {
        case .video: "Video"
        case .web: "Web"
        case .scene: "Scene"
        case .application: "Application"
        }
    }

    init?(tags: [String]) {
        guard let match = Self.allCases.first(where: { tags.contains($0.rawValue) }) else { return nil }
        self = match
    }
}
