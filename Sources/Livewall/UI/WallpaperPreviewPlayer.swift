import AppKit

/// Owns only the inspector's renderer; previewing never changes the desktop selection.
@MainActor
final class WallpaperPreviewPlayer: ObservableObject {
    typealias Factory = (Wallpaper, RenderOptions) throws -> WallpaperRenderer

    @Published private(set) var renderedView: NSView?
    @Published private(set) var error: String?
    @Published var isPlaying = true { didSet { updatePlayback() } }
    @Published var isMuted = true { didSet { renderer?.update(options: options) } }

    private var renderer: WallpaperRenderer?
    private var isVisible = false
    private var factory: Factory?
    private var options: RenderOptions { RenderOptions(muted: isMuted, frameRate: 30) }

    init(factory: Factory? = nil) { self.factory = factory }

    func load(_ wallpaper: Wallpaper, library: WallpaperLibrary) {
        tearDown()
        error = nil
        do {
            if factory == nil, case .libraryFile(let path) = wallpaper.source,
               !FileManager.default.fileExists(atPath: library.fileURL(forRelativePath: path).path) {
                throw CocoaError(.fileReadNoSuchFile)
            }
            let make = factory ?? RendererFactory(resolver: WallpaperAssetResolver(library: library)).makeRenderer
            let next = try make(wallpaper, options)
            renderer = next
            renderedView = next.view
            updatePlayback()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func setVisible(_ visible: Bool) {
        isVisible = visible
        updatePlayback()
    }

    func tearDown() {
        renderer?.tearDown()
        renderer = nil
        renderedView = nil
    }

    private func updatePlayback() {
        guard isVisible && isPlaying else { renderer?.pause(); return }
        renderer?.play()
    }
}
