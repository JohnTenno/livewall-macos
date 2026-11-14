import AppKit
import ImageIO
import Testing
@testable import Livewall

@MainActor
@Suite struct WallpaperPreviewTests {
    @Test func selectionReleasesOldRendererAndHonorsVisibility() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "preview-tests-\(UUID())")
        let library = WallpaperLibrary(rootURL: root)
        defer { try? FileManager.default.removeItem(at: root) }
        var renderers: [PreviewRendererStub] = []
        let player = WallpaperPreviewPlayer { _, options in
            #expect(options.muted)
            #expect(options.frameRate == 30)
            let renderer = PreviewRendererStub()
            renderers.append(renderer)
            return renderer
        }

        player.load(BuiltInShaders.wallpapers[0], library: library)
        let first = try #require(renderers.first)
        #expect(first.playCount == 0)
        player.setVisible(true)
        #expect(first.playCount == 1)
        player.isPlaying = false
        #expect(first.pauseCount >= 1)
        player.isPlaying = true
        player.setVisible(false)
        let playsBeforeHiding = first.playCount
        player.isPlaying = true
        #expect(first.playCount == playsBeforeHiding)

        player.load(BuiltInShaders.wallpapers[1], library: library)
        #expect(first.tearDownCount == 1)
        #expect(renderers.count == 2)
        let second = renderers[1]
        #expect(second.playCount == 0)
        player.setVisible(true)
        #expect(second.playCount == 1)
        player.isMuted = false
        #expect(second.lastOptions?.muted == false)
        #expect(player.renderedView === second.view)
        player.tearDown()
        player.tearDown()
        #expect(second.tearDownCount == 1)
        #expect(player.renderedView == nil)
    }

    @Test func failedSelectionReleasesPreviousRenderer() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "preview-tests-\(UUID())")
        let library = WallpaperLibrary(rootURL: root)
        defer { try? FileManager.default.removeItem(at: root) }
        let renderer = PreviewRendererStub()
        let player = WallpaperPreviewPlayer { wallpaper, _ in
            if wallpaper.id == BuiltInShaders.wallpapers[1].id { throw ShaderError.missingSource }
            return renderer
        }
        player.load(BuiltInShaders.wallpapers[0], library: library)
        player.load(BuiltInShaders.wallpapers[1], library: library)
        #expect(renderer.tearDownCount == 1)
        #expect(player.renderedView == nil)
        #expect(player.error != nil)
    }

    @Test func workshopProvenanceSurvivesRelaunchAndLegacyLibrariesStillDecode() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "preview-tests-\(UUID())")
        let library = WallpaperLibrary(rootURL: root)
        defer { try? FileManager.default.removeItem(at: root) }
        let wallpaper = try library.addWebsite("https://example.com", name: "Test")
        let preview = URL(string: "https://example.com/preview.png")!
        let linked = library.setWorkshopSource(id: "123", previewURL: preview, for: wallpaper)
        #expect(linked.workshopID == "123")
        let reloaded = WallpaperLibrary(rootURL: root)
        #expect(reloaded.userWallpapers.first?.workshopID == "123")
        #expect(reloaded.userWallpapers.first?.previewImageURL == preview)

        let legacy = Data(#"{"id":"6F1D2C1A-4B7E-4C11-9C1E-0A0000000001","name":"Aurora","kind":"shader","source":{"builtInShader":{"_0":"aurora"}}}"#.utf8)
        let decoded = try JSONDecoder().decode(Wallpaper.self, from: legacy)
        #expect(decoded.workshopID == nil)
        #expect(decoded.previewImageURL == nil)
    }

    @Test func webThumbnailUsesTheProjectsPreviewFile() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "preview-tests-\(UUID())")
        let folder = root.appending(path: "web")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "<p>Test</p>".write(to: folder.appending(path: "index.html"), atomically: true, encoding: .utf8)
        try #"{"type":"web","file":"index.html","preview":"poster.png"}"#
            .write(to: folder.appending(path: "project.json"), atomically: true, encoding: .utf8)
        let source = try #require(BuiltInShaders.source(forKey: "aurora"))
        let cgImage = try #require(try WallpaperThumbnails.shaderImage(source: source, size: 32))
        let destination = try #require(CGImageDestinationCreateWithURL(folder.appending(path: "poster.png") as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, cgImage, nil)
        #expect(CGImageDestinationFinalize(destination))
        let library = WallpaperLibrary(rootURL: root.appending(path: "library"))
        let wallpaper = try library.importWebFolder(at: folder, entryFile: "index.html", name: "Web")
        let store = WallpaperThumbnails()
        let image = try #require(await store.image(for: wallpaper, library: library))
        #expect(image.size.width == 32)
        #expect(image.size.height == 32)
        let cached = await store.image(for: wallpaper, library: library)
        #expect(image === cached)
    }

    @Test func builtInThumbnailsRenderRealShaderPixels() throws {
        for wallpaper in BuiltInShaders.wallpapers {
            guard case .builtInShader(let key) = wallpaper.source else { continue }
            let source = try #require(BuiltInShaders.source(forKey: key))
            let image = try #require(try WallpaperThumbnails.shaderImage(source: source, size: 64))
            #expect(image.width == 64)
            #expect(image.height == 64)
            let data = try #require(image.dataProvider?.data) as Data
            #expect(Set(data).count > 8)
        }
    }

    @Test func remotePreviewKeepsAllGIFFrames() throws {
        let bytes = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(bytes, "com.compuserve.gif" as CFString, 2, nil))
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for key in ["aurora", "plasma"] {
            let source = try #require(BuiltInShaders.source(forKey: key))
            let image = try #require(try WallpaperThumbnails.shaderImage(source: source, size: 32))
            CGImageDestinationAddImage(destination, image,
                [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.15]] as CFDictionary)
        }
        #expect(CGImageDestinationFinalize(destination))
        let decoded = try WorkshopPreviewImageLoader.decode(bytes as Data)
        #expect(decoded.frameCount == 2)
        let bitmap = try #require(decoded.image.representations.first as? NSBitmapImageRep)
        #expect(bitmap.value(forProperty: .frameCount) as? Int == 2)
    }

    @Test func invalidRemotePreviewDoesNotBecomeAnImage() {
        #expect(throws: (any Error).self) {
            try WorkshopPreviewImageLoader.decode(Data("not an image".utf8))
        }
    }
}

@MainActor
private final class PreviewRendererStub: WallpaperRenderer {
    let view = NSView()
    var playCount = 0
    var pauseCount = 0
    var tearDownCount = 0
    var lastOptions: RenderOptions?
    func update(options: RenderOptions) { lastOptions = options }
    func play() { playCount += 1 }
    func pause() { pauseCount += 1 }
    func tearDown() { tearDownCount += 1 }
}
