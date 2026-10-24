import AppKit

/// Owns the long-lived services and starts the desktop windows once the app has launched.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    let library = WallpaperLibrary()
    lazy var desktop = DesktopController(library: library, settings: settings)
    lazy var lockScreen = LockScreenModel(resolver: WallpaperAssetResolver(library: library))
    let steamAccount = SteamAccount()
    lazy var workshop = WorkshopModel(account: steamAccount, library: library, settings: settings)
    lazy var desktopVariants = DesktopVariantModel(library: library) { [weak self] id in
        // Switch the running wallpaper to its new copy as soon as it is ready.
        if self?.settings.selectedWallpaperID == id { self?.desktop.reload() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        desktop.start()
        desktopVariants.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        desktop.stop()
    }
}
