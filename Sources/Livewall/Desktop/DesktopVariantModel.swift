import AppKit
import Combine

/// Makes the display-sized desktop copies of every video in the library, one video at a time, in the background.
@MainActor
final class DesktopVariantModel: ObservableObject {
    @Published private(set) var progress: [UUID: Double] = [:]
    @Published private(set) var errors: [UUID: String] = [:]

    private let library: WallpaperLibrary
    private let store: DesktopVariantStore
    private let onFinished: (UUID) -> Void
    private var queue: [Wallpaper] = []
    private var attempted: Set<UUID> = []
    private var isRunning = false
    private var cancellable: AnyCancellable?

    init(library: WallpaperLibrary, onFinished: @escaping (UUID) -> Void) {
        self.library = library
        self.onFinished = onFinished
        store = DesktopVariantStore(libraryRoot: library.rootURL)
    }

    func start() {
        cancellable = library.$userWallpapers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.enqueueMissing($0) }
    }

    func available(for wallpaper: Wallpaper) -> [DesktopVideoQuality] {
        store.available(wallpaperID: wallpaper.id)
    }

    private func enqueueMissing(_ wallpapers: [Wallpaper]) {
        for wallpaper in wallpapers where wallpaper.kind == .video && !attempted.contains(wallpaper.id)
            && !store.isComplete(wallpaperID: wallpaper.id) {
            attempted.insert(wallpaper.id)
            queue.append(wallpaper)
        }
        runNext()
    }

    private func runNext() {
        guard !isRunning, !queue.isEmpty else { return }
        let wallpaper = queue.removeFirst()
        guard case .libraryFile(let path) = wallpaper.source else { return runNext() }
        isRunning = true
        progress[wallpaper.id] = 0
        let source = library.fileURL(forRelativePath: path)
        let store = store
        let display = Self.largestDisplay()
        let id = wallpaper.id
        Task {
            do {
                try await Task.detached(priority: .utility) {
                    try await store.generate(wallpaperID: id, source: source, display: display) { value in
                        Task { @MainActor [weak self] in if self?.progress[id] != nil { self?.progress[id] = value } }
                    }
                }.value
            } catch {
                errors[id] = error.localizedDescription
            }
            progress[id] = nil
            // Deleted while encoding: drop what was written for it.
            if library.wallpaper(id: id) == nil { store.remove(wallpaperID: id) }
            isRunning = false
            onFinished(id)
            runNext()
        }
    }

    /// Largest backing size in pixels among the connected displays.
    private static func largestDisplay() -> CGSize {
        NSScreen.screens.map { CGSize(width: $0.frame.width * $0.backingScaleFactor,
                                      height: $0.frame.height * $0.backingScaleFactor) }
            .max { $0.width * $0.height < $1.width * $1.height } ?? CGSize(width: 3840, height: 2160)
    }
}
