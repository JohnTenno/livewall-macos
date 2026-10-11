import Foundation

@MainActor
final class WebsiteFormModel: ObservableObject {
    @Published var address = "https://"
    @Published var name = ""
    @Published private(set) var error: String?

    /// Adds the site to the library and selects it. Returns false when the address is invalid.
    func submit(library: WallpaperLibrary, settings: AppSettings) -> Bool {
        do {
            settings.selectedWallpaperID = try library.addWebsite(address, name: name).id
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
