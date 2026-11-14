/// Wallpaper Engine's age ratings, stored as Workshop tags.
enum WorkshopRating: String, CaseIterable, Identifiable {
    case everyone = "Everyone"
    case questionable = "Questionable"
    case mature = "Mature"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .everyone: String(localized: "Everyone")
        case .questionable: String(localized: "Questionable")
        case .mature: String(localized: "Mature")
        }
    }
}
