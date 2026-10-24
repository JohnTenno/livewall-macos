import Foundation

/// Turns the current wallpaper into a movie and installs it as the selected Aerial, shown on the lock screen.
@MainActor
final class LockScreenModel: ObservableObject {
    @Published private(set) var aerial: Aerial?
    @Published private(set) var hasBackup = false
    @Published private(set) var isWorking = false
    /// A just-imported video the UI offers to put on the lock screen.
    @Published var offer: Wallpaper?
    /// 0...1 while recording a shader; nil when progress is unknown or idle.
    @Published private(set) var progress: Double?
    @Published private(set) var status: String?
    @Published private(set) var error: String?

    private let resolver: WallpaperAssetResolver
    private let store: AerialStore
    private let spec: VideoExportSpec
    private let cache: LockScreenExportCache
    private let appliedState: LockScreenAppliedState

    init(resolver: WallpaperAssetResolver, store: AerialStore = AerialStore(), spec: VideoExportSpec = .lockScreen) {
        self.resolver = resolver
        self.store = store
        self.spec = spec
        cache = LockScreenExportCache(libraryRoot: resolver.libraryRoot)
        appliedState = LockScreenAppliedState(libraryRoot: resolver.libraryRoot)
        refresh()
    }

    func refresh() {
        aerial = store.selectedAerial()
        hasBackup = aerial.map(store.hasBackup) ?? false
    }

    func isApplied(_ wallpaper: Wallpaper) -> Bool {
        guard let aerial, let revision = try? sourceRevision(wallpaper) else { return false }
        return appliedState.isApplied(wallpaperID: wallpaper.id, sourceRevision: revision, aerial: aerial)
    }

    private func sourceRevision(_ wallpaper: Wallpaper) throws -> String {
        let source: String
        switch wallpaper.kind {
        case .shader: source = try resolver.shaderSource(for: wallpaper)
        case .video:
            let url = try resolver.url(for: wallpaper)
            source = url.path + "|" + (try LockScreenAppliedState.fileRevision(url))
        case .web: throw LockScreenError.unsupportedKind(.web)
        }
        return LockScreenExportCache.key(source: source, minimumDuration: 0, spec: spec)
    }

    func apply(_ wallpaper: Wallpaper) {
        guard !isWorking else { return }
        refresh()
        guard let aerial else { return fail(LockScreenError.noAerialSelected) }
        guard aerial.isDownloaded else { return fail(LockScreenError.aerialNotDownloaded(aerial.name)) }
        guard !isApplied(wallpaper) else { return }
        let revision: String
        do { revision = try sourceRevision(wallpaper) } catch { return fail(error) }

        let temp = FileManager.default.temporaryDirectory
        let exportID = UUID().uuidString
        let recording = temp.appending(path: "livewall-\(exportID)-recording.mov")
        let report: (Double) -> Void = { [weak self] value in
            Task { @MainActor in self?.progress = value }
        }

        // Produces a source movie and the share of the progress bar it used (shaders are recorded first).
        let makeSource: () async throws -> (URL, Double)
        let fingerprint: () throws -> String
        do {
            switch wallpaper.kind {
            case .shader:
                let shader = try resolver.shaderSource(for: wallpaper)
                let spec = spec
                fingerprint = { LockScreenExportCache.fingerprint(text: shader) }
                makeSource = {
                    let recorder = try ShaderVideoRecorder(source: shader, spec: spec)
                    try await recorder.record(to: recording) { report($0 * 0.4) }
                    return (recording, 0.4)
                }
            case .video:
                let source = try resolver.url(for: wallpaper)
                fingerprint = { try LockScreenExportCache.fingerprint(file: source) }
                makeSource = { (source, 0) }
            case .web:
                throw LockScreenError.unsupportedKind(.web)
            }
        } catch {
            return fail(error)
        }

        isWorking = true
        progress = nil
        status = "Checking saved lock screen video…"
        error = nil

        let store = store, cache = cache, spec = spec, appliedState = appliedState
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    defer { try? FileManager.default.removeItem(at: recording) }
                    let original = await AerialMovieEncoder.duration(of: store.originalVideoURL(for: aerial))
                    guard original.seconds.isFinite, original.seconds > 0 else {
                        throw LockScreenError.encodingFailed("could not read the original Aerial duration")
                    }
                    let key = LockScreenExportCache.key(source: try fingerprint(), minimumDuration: original.seconds, spec: spec)
                    let reused = cache.movie(wallpaperID: wallpaper.id, key: key) != nil
                    await MainActor.run {
                        self.status = reused ? "Reusing saved lock screen video…" : "Rendering 4K 240 fps video of “\(wallpaper.name)”…"
                        self.progress = reused ? nil : 0
                    }
                    let encoded = try await cache.resolve(wallpaperID: wallpaper.id, key: key) { destination in
                        let (source, offset) = try await makeSource()
                        try await AerialMovieEncoder().encode(source, minimumDuration: original, to: destination) { value in
                            report(offset + value * (1 - offset))
                        }
                    }
                    // A user may delete the library item while a long export is running.
                    let stillAvailable = await MainActor.run { self.resolver.contains(wallpaper) }
                    guard stillAvailable else {
                        cache.remove(wallpaperID: wallpaper.id)
                        throw CocoaError(.fileNoSuchFile)
                    }
                    try store.install(encoded, for: aerial)
                    try appliedState.record(wallpaperID: wallpaper.id, sourceRevision: revision, aerial: aerial)
                }.value
                status = "Done. Lock the screen (⌃⌘Q) to see it."
            } catch {
                fail(error)
            }
            isWorking = false
            progress = nil
            refresh()
            // A 4K export peaks near 800 MB; hand the freed pages back instead of keeping them for the app's lifetime.
            malloc_zone_pressure_relief(nil, 0)
        }

    }

    func restore() {
        guard !isWorking, let aerial else { return }
        do {
            try store.restore(aerial)
            appliedState.clear(aerial)
            status = "Restored the original Aerial “\(aerial.name)”."
            error = nil
        } catch {
            fail(error)
        }
        refresh()
    }

    private func fail(_ error: Error) {
        status = nil
        self.error = error.localizedDescription
    }
}
