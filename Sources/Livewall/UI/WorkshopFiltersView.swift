import SwiftUI

/// Wallpaper Engine-style filter panel for the Workshop: type, age rating, category, resolution and features.
struct WorkshopFiltersView: View {
    @Binding var filters: WorkshopFilters

    var body: some View {
        Form {
            Picker("Type", selection: $filters.type) {
                Text("Video and web").tag(WorkshopItemType?.none)
                ForEach(WorkshopItemType.allCases.filter(\.isSupported)) { Text($0.displayName).tag(Optional($0)) }
            }

            Section("Age rating") {
                ForEach(WorkshopRating.allCases) { rating in
                    Toggle(rating.displayName, isOn: Binding(
                        get: { filters.ratings.contains(rating) },
                        set: { on in if on { filters.ratings.insert(rating) } else { filters.ratings.remove(rating) } }
                    ))
                    // At least one rating must stay on, or nothing could match.
                    .disabled(filters.ratings == [rating])
                }
            }

            Section("Category") {
                Picker("Category", selection: $filters.category) {
                    Text("Any category").tag(String?.none)
                    ForEach(WorkshopTags.categories, id: \.self) { Text(LocalizedStringKey($0)).tag(Optional($0)) }
                }
                Picker("Resolution", selection: $filters.resolution) {
                    Text("Any resolution").tag(String?.none)
                    ForEach(WorkshopTags.resolutions, id: \.self) { Text(LocalizedStringKey($0)).tag(Optional($0)) }
                }
            }

            Section("Features") {
                ForEach(WorkshopTags.features, id: \.self) { feature in
                    Toggle(LocalizedStringKey(feature), isOn: Binding(
                        get: { filters.features.contains(feature) },
                        set: { on in if on { filters.features.insert(feature) } else { filters.features.remove(feature) } }
                    ))
                }
            }

            Button("Reset filters") { filters = WorkshopFilters() }
                .disabled(filters == WorkshopFilters())
        }
        .formStyle(.grouped)
        // The search bar hides its labels; the panel needs them.
        .labelsVisibility(.visible)
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
    }
}
