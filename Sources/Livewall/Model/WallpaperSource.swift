import Foundation

/// Where a wallpaper's content lives.
enum WallpaperSource: Codable, Hashable {
    /// Path relative to the library's items folder (a file, or `folder/index.html` for web bundles).
    case libraryFile(String)
    /// A remote web page.
    case remote(URL)
    /// Key into `BuiltInShaders`.
    case builtInShader(String)
}
