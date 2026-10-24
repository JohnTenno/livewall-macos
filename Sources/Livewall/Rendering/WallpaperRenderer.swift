import AppKit

/// Something that draws a wallpaper into a view and can be paused to save power.
@MainActor
protocol WallpaperRenderer: AnyObject {
    var view: NSView { get }
    func update(options: RenderOptions)
    func play()
    func pause()
    /// Releases players, GPU work and web content. The renderer is unusable afterwards.
    func tearDown()
}
