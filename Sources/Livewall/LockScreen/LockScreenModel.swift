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

        let movie = FileManager.default.temporaryDirectory.appending(path: "livewall-lockscreen.mov")
        let job: () async throws -> Void
        do {
            switch wallpaper.kind {
            case .shader:
                let recorder = try ShaderVideoRecorder(source: try resolver.shaderSource(for: wallpaper), spec: spec)
                job = { [weak self] in
                    try await recorder.record(to: movie) { value in
                        Task { @MainActor in self?.progress = value }
                    }
                }
            case .video:
                let source = try resolver.url(for: wallpaper)
                job = { try await VideoTranscoder().transcode(source, to: movie) }
            case .web:
                throw LockScreenError.unsupportedKind(.web)
            }
        } catch {
            return fail(error)
        }

        isWorking = true
        progress = wallpaper.kind == .shader ? 0 : nil
        status = "Generando video 4K de «\(wallpaper.name)»…"
        error = nil

        let store = store
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try await job()
                    try store.install(movie, for: aerial)
                    try? FileManager.default.removeItem(at: movie)
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
