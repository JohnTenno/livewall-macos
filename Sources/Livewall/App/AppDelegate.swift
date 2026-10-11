import AppKit

/// Owns the long-lived services and starts the desktop windows once the app has launched.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    let library = WallpaperLibrary()
    lazy var desktop = DesktopController(library: library, settings: settings)

    func applicationDidFinishLaunching(_ notification: Notification) {
        desktop.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        desktop.stop()
    }
}
