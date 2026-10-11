import Foundation

/// Builds the right renderer for a wallpaper, resolving its source through the library.
@MainActor
final class RendererFactory {
    private let library: WallpaperLibrary

    init(library: WallpaperLibrary) {
        self.library = library
    }

    func makeRenderer(for wallpaper: Wallpaper, options: RenderOptions) throws -> WallpaperRenderer {
        switch wallpaper.kind {
        case .video:
            return VideoRenderer(url: try url(for: wallpaper), options: options)
        case .web:
            return WebRenderer(url: try url(for: wallpaper), options: options)
        case .shader:
            return try ShaderRenderer(source: try shaderSource(for: wallpaper), options: options)
        }
    }

    private func url(for wallpaper: Wallpaper) throws -> URL {
        switch wallpaper.source {
        case .libraryFile(let path): library.fileURL(forRelativePath: path)
        case .remote(let url): url
        case .builtInShader: throw ShaderError.missingSource
        }
    }

    private func shaderSource(for wallpaper: Wallpaper) throws -> String {
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
