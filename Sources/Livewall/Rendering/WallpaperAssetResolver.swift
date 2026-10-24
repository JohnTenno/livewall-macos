import Foundation

/// Turns a wallpaper's source into something loadable: a URL for video/web, Metal source for shaders.
@MainActor
final class WallpaperAssetResolver {
    private let library: WallpaperLibrary

    init(library: WallpaperLibrary) {
        self.library = library
    }

    var libraryRoot: URL { library.rootURL }

    func contains(_ wallpaper: Wallpaper) -> Bool { library.wallpaper(id: wallpaper.id) != nil }

    func url(for wallpaper: Wallpaper) throws -> URL {
        switch wallpaper.source {
        case .libraryFile(let path): library.fileURL(forRelativePath: path)
        case .remote(let url): url
        case .builtInShader: throw ShaderError.missingSource
        }
    }

    /// What the desktop plays: the chosen display-sized copy of a video when it exists, else `url(for:)`.
    /// The lock screen keeps using `url(for:)`, i.e. the original file.
    func desktopURL(for wallpaper: Wallpaper) throws -> URL {
        if wallpaper.kind == .video,
           let copy = DesktopVariantStore(libraryRoot: library.rootURL)
               .url(wallpaperID: wallpaper.id, quality: wallpaper.effectiveDesktopQuality) {
            return copy
        }
        return try url(for: wallpaper)
    }

    func shaderSource(for wallpaper: Wallpaper) throws -> String {
        switch wallpaper.source {
        case .builtInShader(let key):
            guard let source = BuiltInShaders.source(forKey: key) else { throw ShaderError.missingSource }
            return source
        case .libraryFile(let path):
            return try String(contentsOf: library.fileURL(forRelativePath: path), encoding: .utf8)
        case .remote:
            throw ShaderError.missingSource
        }
    }
}
