import Foundation

/// Turns a wallpaper's source into something loadable: a URL for video/web, Metal source for shaders.
@MainActor
final class WallpaperAssetResolver {
    private let library: WallpaperLibrary

    init(library: WallpaperLibrary) {
        self.library = library
    }

    func url(for wallpaper: Wallpaper) throws -> URL {
        switch wallpaper.source {
        case .libraryFile(let path): library.fileURL(forRelativePath: path)
        case .remote(let url): url
        case .builtInShader: throw ShaderError.missingSource
        }
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
