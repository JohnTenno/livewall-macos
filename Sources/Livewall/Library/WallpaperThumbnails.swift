import AppKit
import AVFoundation
import Metal
import ImageIO

/// Static thumbnails are cached; scrolling the grid never starts wallpaper players.
@MainActor
final class WallpaperThumbnails {
    static let shared = WallpaperThumbnails()
    private let cache = NSCache<NSString, NSImage>()
    private var pending: [String: Task<CGImage?, Never>] = [:]

    init() { cache.countLimit = 150 }

    func image(for wallpaper: Wallpaper, library: WallpaperLibrary) async -> NSImage? {
        let resolver = WallpaperAssetResolver(library: library)
        let sourceURL = try? resolver.url(for: wallpaper)
        let modified = sourceURL.flatMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
        let key = library.rootURL.path + wallpaper.id.uuidString + String(describing: modified)
        if let image = cache.object(forKey: key as NSString) { return image }
        let task: Task<CGImage?, Never>
        if let existing = pending[key] {
            task = existing
        } else {
            let source = wallpaper.kind == .shader ? try? resolver.shaderSource(for: wallpaper) : nil
            task = Task.detached(priority: .utility) {
                switch wallpaper.kind {
                case .video:
                    guard let sourceURL else { return nil }
                    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: sourceURL))
                    generator.appliesPreferredTrackTransform = true
                    generator.maximumSize = CGSize(width: 480, height: 480)
                    return try? await generator.image(at: .zero).image
                case .shader:
                    guard let source else { return nil }
                    return try? Self.shaderImage(source: source)
                case .web:
                    if let sourceURL, sourceURL.isFileURL {
                        let folder = sourceURL.deletingLastPathComponent()
                        let projectPreview = try? WallpaperEngineProject.load(from: folder).preview
                        let names = [projectPreview, "preview.jpg", "preview.png", "preview.gif"].compactMap { $0 }
                        for name in names {
                            let url = folder.appending(path: name)
                            if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                               let image = CGImageSourceCreateImageAtIndex(source, 0, nil) { return image }
                        }
                    }
                    if let url = wallpaper.previewImageURL,
                       let (data, _) = try? await URLSession.shared.data(from: url),
                       let source = CGImageSourceCreateWithData(data as CFData, nil) {
                        return CGImageSourceCreateImageAtIndex(source, 0, nil)
                    }
                    return nil
                }
            }
            pending[key] = task
        }
        let result = await task.value
        pending[key] = nil
        guard let result else { return nil }
        let image = NSImage(cgImage: result, size: CGSize(width: result.width, height: result.height))
        cache.setObject(image, forKey: key as NSString)
        return image
    }

    /// Produces one real shader frame on a background task, without an animation loop.
    nonisolated static func shaderImage(source: String, size: Int = 320) throws -> CGImage? {
        let pipeline = try ShaderPipeline(userSource: source)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: ShaderPipeline.pixelFormat,
            width: size, height: size, mipmapped: false)
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = .shared
        guard let texture = pipeline.device.makeTexture(descriptor: descriptor),
              let queue = pipeline.device.makeCommandQueue(), let buffer = queue.makeCommandBuffer() else { return nil }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return nil }
        var uniforms = ShaderUniforms(resolution: SIMD2(repeating: Float(size)),
            mouse: SIMD2(repeating: Float(size) / 2), time: 1)
        encoder.setRenderPipelineState(pipeline.state)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<ShaderUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        buffer.commit()
        buffer.waitUntilCompleted()
        guard buffer.status == .completed else { return nil }
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        pixels.withUnsafeMutableBytes { bytes in
            texture.getBytes(bytes.baseAddress!, bytesPerRow: size * 4,
                from: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0)
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: [.byteOrder32Little, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)],
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
