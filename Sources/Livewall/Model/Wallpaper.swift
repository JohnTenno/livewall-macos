import Foundation

/// A wallpaper entry in the library.
struct Wallpaper: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var kind: WallpaperKind
    var source: WallpaperSource
    /// Videos only; nil means the recommended optimized copy once it exists.
    var desktopQuality: DesktopVideoQuality? = nil

    var effectiveDesktopQuality: DesktopVideoQuality { desktopQuality ?? .optimized }

    var isBuiltIn: Bool {
        if case .builtInShader = source { return true }
        return false
    }
}
