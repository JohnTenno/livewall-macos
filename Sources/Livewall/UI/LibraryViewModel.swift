import Foundation

/// Presentation state and actions for `LibraryView`.
@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var isImporting = false
    @Published var isAddingWebsite = false
    @Published var importError: String?

    func importFiles(_ result: Result<[URL], Error>, library: WallpaperLibrary, settings: AppSettings) {
        do {
            var lastImported: Wallpaper?
            for url in try result.get() {
                lastImported = try library.importItem(at: url)
            }
            if let lastImported {
                settings.selectedWallpaperID = lastImported.id
            }
        } catch {
            importError = error.localizedDescription
        }
    }

    func remove(_ wallpaper: Wallpaper, library: WallpaperLibrary, settings: AppSettings) {
        if settings.selectedWallpaperID == wallpaper.id {
            settings.selectedWallpaperID = nil
        }
        library.remove(wallpaper)
    }
}
