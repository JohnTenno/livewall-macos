import Foundation

/// A wallpaper entry in the library.
struct Wallpaper: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var kind: WallpaperKind
    var source: WallpaperSource

    var isBuiltIn: Bool {
        if case .builtInShader = source { return true }
        return false
    }
}
