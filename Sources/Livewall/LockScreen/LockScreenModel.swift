import Foundation

/// Turns the current wallpaper into a movie and installs it as the selected Aerial, shown on the lock screen.
@MainActor
final class LockScreenModel: ObservableObject {
    @Published private(set) var aerial: Aerial?
    @Published private(set) var hasBackup = false
    @Published private(set) var isWorking = false
    /// 0...1 while recording a shader; nil when progress is unknown or idle.
    @Published private(set) var progress: Double?
    @Published private(set) var status: String?
    @Published private(set) var error: String?

    private let resolver: WallpaperAssetResolver
    private let store: AerialStore
    private let spec: VideoExportSpec

    init(resolver: WallpaperAssetResolver, store: AerialStore = AerialStore(), spec: VideoExportSpec = .lockScreen) {
        self.resolver = resolver
        self.store = store
        self.spec = spec
        refresh()
    }

    func refresh() {
        aerial = store.selectedAerial()
        hasBackup = aerial.map(store.hasBackup) ?? false
    }

    func apply(_ wallpaper: Wallpaper) {
        refresh()
        guard let aerial else { return fail(LockScreenError.noAerialSelected) }
        guard aerial.isDownloaded else { return fail(LockScreenError.aerialNotDownloaded(aerial.name)) }

        let temp = FileManager.default.temporaryDirectory
        let recording = temp.appending(path: "livewall-lockscreen-recording.mov")
        let encoded = temp.appending(path: "livewall-lockscreen-aerial.mov")
        let report: (Double) -> Void = { [weak self] value in
            Task { @MainActor in self?.progress = value }
        }

        // Produces a source movie and the share of the progress bar it used (shaders are recorded first).
        let makeSource: () async throws -> (URL, Double)
        do {
            switch wallpaper.kind {
            case .shader:
                let recorder = try ShaderVideoRecorder(source: try resolver.shaderSource(for: wallpaper), spec: spec)
                makeSource = {
                    try await recorder.record(to: recording) { report($0 * 0.4) }
                    return (recording, 0.4)
                }
            case .video:
                let source = try resolver.url(for: wallpaper)
                makeSource = { (source, 0) }
            case .web:
                throw LockScreenError.unsupportedKind(.web)
            }
        } catch {
            return fail(error)
        }

        isWorking = true
        progress = 0
        status = "Generando video 4K a 240 fps de «\(wallpaper.name)»…"
        error = nil

        let store = store
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    let (source, offset) = try await makeSource()
                    // Must cover every point of interest of Apple's original, or the lock screen freezes on resume.
                    let original = await AerialMovieEncoder.duration(of: store.originalVideoURL(for: aerial))
                    try await AerialMovieEncoder().encode(source, minimumDuration: original, to: encoded) { value in
                        report(offset + value * (1 - offset))
                    }
                    try store.install(encoded, for: aerial)
                    try? FileManager.default.removeItem(at: recording)
                    try? FileManager.default.removeItem(at: encoded)
                }.value
                status = "Listo. Bloquea la pantalla (⌃⌘Q) para verlo."
            } catch {
                fail(error)
            }
            isWorking = false
            progress = nil
            refresh()
        }

    }

    func restore() {
        guard let aerial else { return }
        do {
            try store.restore(aerial)
            status = "Se restauró el Aerial original «\(aerial.name)»."
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
