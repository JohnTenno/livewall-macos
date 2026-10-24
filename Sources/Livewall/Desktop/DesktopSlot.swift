import AppKit

/// One display's desktop window and the renderer currently shown in it.
@MainActor
final class DesktopSlot {
    let isPrimary: Bool
    var onVisibilityChange: (() -> Void)?

    private let window: DesktopWindow
    private var renderer: WallpaperRenderer?
    private var isPlaying: Bool?
    private var occlusionObserver: NSObjectProtocol?

    init(screen: NSScreen, isPrimary: Bool) {
        self.isPrimary = isPrimary
        window = DesktopWindow(screen: screen)
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.onVisibilityChange?() }
        }
    }

    /// False when other windows (e.g. a full-screen app) completely cover the desktop.
    var isVisibleOnScreen: Bool { window.occlusionState.contains(.visible) }

    func show(_ newRenderer: WallpaperRenderer) {
        renderer?.tearDown()
        renderer = newRenderer
        isPlaying = nil
        window.contentView = newRenderer.view
        window.orderFrontRegardless()
    }

    /// Removes the renderer and hides the window so the system wallpaper shows through.
    func clear() {
        renderer?.tearDown()
        renderer = nil
        isPlaying = nil
        window.orderOut(nil)
        window.contentView = nil
    }

    func update(options: RenderOptions) {
        renderer?.update(options: options)
    }

    func setPlaying(_ playing: Bool) {
        guard renderer != nil, isPlaying != playing else { return }
        isPlaying = playing
        if playing {
            renderer?.play()
        } else {
            renderer?.pause()
        }
    }

    func close() {
        clear()
        if let occlusionObserver {
            NotificationCenter.default.removeObserver(occlusionObserver)
        }
        window.close()
    }
}
