import Foundation

/// User preferences, persisted in UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let selectedWallpaper = "selectedWallpaperID"
        static let isPaused = "isPaused"
        static let pauseWhenCovered = "pauseWhenCovered"
        static let pauseOnBattery = "pauseOnBattery"
        static let muted = "muted"
        static let frameRate = "frameRate"
    }

    /// Stored instead of removing the key, so "no wallpaper" survives relaunch without falling back to the default.
    private static let noneSentinel = "none"

    static let frameRateOptions = [30, 60, 120]

    private let defaults: UserDefaults

    @Published var selectedWallpaperID: UUID? {
        didSet { defaults.set(selectedWallpaperID?.uuidString ?? Self.noneSentinel, forKey: Key.selectedWallpaper) }
    }
    @Published var isPaused: Bool {
        didSet { defaults.set(isPaused, forKey: Key.isPaused) }
    }
    @Published var pauseWhenCovered: Bool {
        didSet { defaults.set(pauseWhenCovered, forKey: Key.pauseWhenCovered) }
    }
    @Published var pauseOnBattery: Bool {
        didSet { defaults.set(pauseOnBattery, forKey: Key.pauseOnBattery) }
    }
    @Published var muted: Bool {
        didSet { defaults.set(muted, forKey: Key.muted) }
    }
    @Published var frameRate: Int {
        didSet { defaults.set(frameRate, forKey: Key.frameRate) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.pauseWhenCovered: true,
            Key.pauseOnBattery: false,
            Key.muted: true,
            Key.frameRate: 60,
        ])

        switch defaults.string(forKey: Key.selectedWallpaper) {
        case nil: selectedWallpaperID = BuiltInShaders.wallpapers.first?.id
        case Self.noneSentinel?: selectedWallpaperID = nil
        case let stored?: selectedWallpaperID = UUID(uuidString: stored)
        }
        isPaused = defaults.bool(forKey: Key.isPaused)
        pauseWhenCovered = defaults.bool(forKey: Key.pauseWhenCovered)
        pauseOnBattery = defaults.bool(forKey: Key.pauseOnBattery)
        muted = defaults.bool(forKey: Key.muted)
        frameRate = defaults.integer(forKey: Key.frameRate)
    }
}
