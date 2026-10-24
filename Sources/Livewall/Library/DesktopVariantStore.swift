import Foundation

/// Display-sized copies of video wallpapers, in `DesktopVariants/<wallpaper id>/`. Originals are never touched.
final class DesktopVariantStore: Sendable {
    private let root: URL

    init(libraryRoot: URL = WallpaperLibrary.defaultRootURL) {
        root = libraryRoot.appending(path: "DesktopVariants", directoryHint: .isDirectory)
    }

    /// The copy for `quality`, or nil when it does not exist (yet, or because it would not help).
    func url(wallpaperID: UUID, quality: DesktopVideoQuality) -> URL? {
        guard quality != .original else { return nil }
        let url = file(wallpaperID, quality)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func available(wallpaperID: UUID) -> [DesktopVideoQuality] {
        DesktopVideoQuality.allCases.filter { $0 == .original || url(wallpaperID: wallpaperID, quality: $0) != nil }
    }

    /// True once every planned copy was written, including when none was worth making.
    func isComplete(wallpaperID: UUID) -> Bool {
        FileManager.default.fileExists(atPath: marker(wallpaperID).path)
    }

    func remove(wallpaperID: UUID) {
        try? FileManager.default.removeItem(at: directory(wallpaperID))
    }

    func generate(wallpaperID: UUID, source: URL, display: CGSize,
                  progress: @escaping @Sendable (Double) -> Void) async throws {
        let probe = try await DesktopVideoEncoder.probe(source)
        let plan = DesktopVariantPlan(sourceSize: probe.size, sourceFrameRate: probe.frameRate, display: display)
        try FileManager.default.createDirectory(at: directory(wallpaperID), withIntermediateDirectories: true)
        for (index, variant) in plan.variants.enumerated() {
            let destination = file(wallpaperID, variant.quality)
            try? FileManager.default.removeItem(at: destination)
            let share = 1 / Double(plan.variants.count)
            try await DesktopVideoEncoder().encode(source: source, destination: destination, size: variant.size,
                                                   frameRate: variant.frameRate) { value in
                progress((Double(index) + value) * share)
            }
        }
        try Data().write(to: marker(wallpaperID))
    }

    private func directory(_ id: UUID) -> URL { root.appending(path: id.uuidString, directoryHint: .isDirectory) }
    private func file(_ id: UUID, _ quality: DesktopVideoQuality) -> URL { directory(id).appending(path: "\(quality.rawValue).mov") }
    private func marker(_ id: UUID) -> URL { directory(id).appending(path: "complete") }
}
