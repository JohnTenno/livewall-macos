/// Everything beyond the search text that narrows Workshop results, mirroring Wallpaper Engine's filter panel.
struct WorkshopFilters: Equatable {
    /// Nil means every type Livewall can play (video or web).
    var type: WorkshopItemType?
    var ratings: Set<WorkshopRating> = [.everyone]
    var category: String?
    var resolution: String?
    var features: Set<String> = []

    /// How many filters differ from the defaults, for the Filters button badge.
    var activeCount: Int {
        (type == nil ? 0 : 1) + (ratings == [.everyone] ? 0 : 1) + (category == nil ? 0 : 1)
            + (resolution == nil ? 0 : 1) + features.count
    }

    /// Tags every result must have (Steam is asked to match all of them).
    var requiredTags: [String] {
        [type?.rawValue, category, resolution].compactMap { $0 } + features.sorted()
    }

    /// Steam cannot OR tags together with other filters, so "video or web" and the allowed ratings
    /// are expressed by excluding everything else.
    var excludedTags: [String] {
        let types = type == nil ? WorkshopItemType.allCases.filter { !$0.isSupported }.map(\.rawValue) : []
        let ratings = WorkshopRating.allCases.filter { !self.ratings.contains($0) }.map(\.rawValue)
        return types + ratings
    }
}
