import Foundation

/// Builds the right renderer for a wallpaper.
@MainActor
final class RendererFactory {
    private let resolver: WallpaperAssetResolver

    init(resolver: WallpaperAssetResolver) {
        self.resolver = resolver
    }

    func makeRenderer(for wallpaper: Wallpaper, options: RenderOptions) throws -> WallpaperRenderer {
        switch wallpaper.kind {
        case .video:
            return VideoRenderer(url: try resolver.desktopURL(for: wallpaper), options: options)
        case .web:
            return WebRenderer(url: try resolver.url(for: wallpaper), options: options)
        case .shader:
            return try ShaderRenderer(source: try resolver.shaderSource(for: wallpaper), options: options)
        }
    }
}
