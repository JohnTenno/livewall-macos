/// The time window for "Most popular", like Wallpaper Engine's period menu. Steam calls it `days`.
enum WorkshopPeriod: Int, CaseIterable, Identifiable {
    case today = 1
    case week = 7
    case month = 30
    case threeMonths = 90
    case sixMonths = 180
    case year = 365
    case allTime = 0

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .today: String(localized: "Today")
        case .week: String(localized: "This week")
        case .month: String(localized: "This month")
        case .threeMonths: String(localized: "Last 3 months")
        case .sixMonths: String(localized: "Last 6 months")
        case .year: String(localized: "This year")
        case .allTime: String(localized: "All time")
        }
    }
}
