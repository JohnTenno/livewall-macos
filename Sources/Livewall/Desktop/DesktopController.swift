import AppKit
import Combine

/// Keeps one desktop window per display showing the selected wallpaper, and pauses it when nobody can see it.
@MainActor
final class DesktopController: ObservableObject {
    @Published private(set) var lastError: String?

    private let library: WallpaperLibrary
    private let settings: AppSettings
    private let factory: RendererFactory
    private let policy = PlaybackPolicy()
    private var slots: [DesktopSlot] = []
    private var cancellables: Set<AnyCancellable> = []

    init(library: WallpaperLibrary, settings: AppSettings) {
        self.library = library
        self.settings = settings
        factory = RendererFactory(resolver: WallpaperAssetResolver(library: library))
    }

    func start() {
        guard cancellables.isEmpty else { return }
        policy.onChange = { [weak self] in self?.updatePlayback() }

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.rebuildSlots() }
            .store(in: &cancellables)

        // @Published emits on willSet, so hop to the next main-queue turn to read the updated values.
        settings.$selectedWallpaperID.removeDuplicates().dropFirst()
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in self?.applyWallpaper() }
        .store(in: &cancellables)

        Publishers.Merge(
            settings.$muted.removeDuplicates().dropFirst().map { _ in () },
            settings.$frameRate.removeDuplicates().dropFirst().map { _ in () }
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in self?.updateOptions() }
        .store(in: &cancellables)

        Publishers.Merge3(
            settings.$isPaused.dropFirst().map { _ in () },
            settings.$pauseOnBattery.dropFirst().map { _ in () },
            settings.$pauseWhenCovered.dropFirst().map { _ in () }
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in self?.updatePlayback() }
        .store(in: &cancellables)

        rebuildSlots()
    }

    func stop() {
        cancellables.removeAll()
        policy.onChange = nil
        closeSlots()
    }

    private func closeSlots() {
        slots.forEach { $0.close() }
        slots.removeAll()
    }

    /// Re-creates the current wallpaper, e.g. after editing its files on disk.
    func reload() {
        applyWallpaper()
    }

    private func rebuildSlots() {
        closeSlots()
        let primary = NSScreen.screens.first
        slots = NSScreen.screens.map { screen in
            let slot = DesktopSlot(screen: screen, isPrimary: screen == primary)
            slot.onVisibilityChange = { [weak self] in self?.updatePlayback() }
            return slot
        }
        applyWallpaper()
    }

    private func applyWallpaper() {
        lastError = nil
        guard let id = settings.selectedWallpaperID, let wallpaper = library.wallpaper(id: id) else {
            slots.forEach { $0.clear() }
            return
        }

        for slot in slots {
            // Only one display plays audio, otherwise multi-monitor setups hear an echo.
            let options = RenderOptions(muted: settings.muted || !slot.isPrimary, frameRate: settings.frameRate)
            do {
                slot.show(try factory.makeRenderer(for: wallpaper, options: options))
            } catch {
                slot.clear()
                lastError = "\(wallpaper.name): \(error.localizedDescription)"
            }
        }
        updatePlayback()
    }

    private func updateOptions() {
        for slot in slots {
            slot.update(options: RenderOptions(muted: settings.muted || !slot.isPrimary, frameRate: settings.frameRate))
        }
    }

    private func updatePlayback() {
        let allowed = policy.allowsPlayback(settings: settings)
        for slot in slots {
            slot.setPlaying(allowed && (!settings.pauseWhenCovered || slot.isVisibleOnScreen))
        }
    }
}
