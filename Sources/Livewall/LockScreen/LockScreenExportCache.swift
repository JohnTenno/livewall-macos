import CryptoKit
import Foundation

/// Persistent, completed exports. Switching wallpapers or restoring Apple’s original keeps these files.
/// Bump the recipe version when the encoder or shader recording contract changes.
final class LockScreenExportCache {
    private let root: URL
    private let files = FileManager.default

    init(libraryRoot: URL = WallpaperLibrary.defaultRootURL) {
        root = libraryRoot.appending(path: "LockScreenExports", directoryHint: .isDirectory)
    }

    static func fingerprint(file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hash = SHA256()
        // Drain each chunk so hashing a large video does not keep every read buffer alive until the loop ends.
        while try autoreleasepool(invoking: {
            guard let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty else { return false }
            hash.update(data: chunk)
            return true
        }) {}
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func fingerprint(text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func key(source: String, minimumDuration: Double, spec: VideoExportSpec) -> String {
        // The final Aerial encoder currently has a fixed format; version that contract explicitly.
        fingerprint(text: "aerial-main10-240-v1|\(source)|\(minimumDuration)|" +
            "\(spec.width)|\(spec.height)|\(spec.frameRate)|\(spec.duration)|\(spec.crossfade)|\(spec.bitRate)")
    }

    func movie(wallpaperID: UUID, key: String) -> URL? {
        let url = directory(wallpaperID).appending(path: "\(key).mov")
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              values.isRegularFile == true, (values.fileSize ?? 0) > 0 else { return nil }
        return url
    }

    /// Only publish after production succeeds. Partial exports never become cache hits.
    func resolve(wallpaperID: UUID, key: String, produce: (URL) async throws -> Void) async throws -> URL {
        if let existing = movie(wallpaperID: wallpaperID, key: key) { return existing }
        let folder = directory(wallpaperID)
        try files.createDirectory(at: folder, withIntermediateDirectories: true)
        let staging = folder.appending(path: ".\(UUID().uuidString).mov")
        defer { try? files.removeItem(at: staging) }
        try await produce(staging)
        try Task.checkCancellation()
        let size = try staging.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0 else { throw LockScreenError.encodingFailed("empty export") }
        let destination = folder.appending(path: "\(key).mov")
        // A prior interrupted/corrupt empty file must not prevent regeneration.
        if files.fileExists(atPath: destination.path) { try files.removeItem(at: destination) }
        try files.moveItem(at: staging, to: destination)
        return destination
    }

    func remove(wallpaperID: UUID) {
        try? files.removeItem(at: directory(wallpaperID))
    }

    private func directory(_ id: UUID) -> URL {
        root.appending(path: id.uuidString, directoryHint: .isDirectory)
    }
}
