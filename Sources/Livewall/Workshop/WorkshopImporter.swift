import Foundation

/// Converts a downloaded Wallpaper Engine item into a Livewall library entry.
@MainActor
final class WorkshopImporter {
    private let library: WallpaperLibrary

    init(library: WallpaperLibrary) {
        self.library = library
    }

    func importItem(at folder: URL, fallbackTitle: String) throws -> Wallpaper {
        let project = try WallpaperEngineProject.load(from: folder)
        let title = project.title ?? fallbackTitle
        guard let file = project.file, !file.isEmpty else {
            throw WorkshopError.unsupportedProject(project.type ?? "desconocido")
        }

        switch project.type?.lowercased() {
        case "video":
            return try library.importItem(at: folder.appending(path: file), name: title)
        case "web":
            // Keep the whole folder: the page loads scripts, images and project.json relative to itself.
            return try library.importWebFolder(at: folder, entryFile: file, name: title)
        default:
            throw WorkshopError.unsupportedProject(project.type ?? "desconocido")
        }
    }
}
