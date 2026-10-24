import Foundation

/// A receipt for the movie actually installed, distinct from reusable converted movies.
final class LockScreenAppliedState {
    private struct Receipt: Codable {
        let wallpaperID: UUID
        let sourceRevision: String
        let movieRevision: String
    }
    private let root: URL

    init(libraryRoot: URL) {
        root = libraryRoot.appending(path: "LockScreenApplied")
    }

    /// Cheap identity check for local files; replacement, resizing and modification invalidate it.
    static func fileRevision(_ url: URL) throws -> String {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber,
              let modified = attributes[.modificationDate] as? Date,
              let inode = attributes[.systemFileNumber] as? NSNumber else {
            throw CocoaError(.fileReadUnknown)
        }
        return "\(size)|\(modified.timeIntervalSince1970)|\(inode)"
    }

    func isApplied(wallpaperID: UUID, sourceRevision: String, aerial: Aerial) -> Bool {
        guard let data = try? Data(contentsOf: file(aerial)),
              let receipt = try? JSONDecoder().decode(Receipt.self, from: data),
              receipt.wallpaperID == wallpaperID, receipt.sourceRevision == sourceRevision,
              let current = try? Self.fileRevision(aerial.videoURL) else { return false }
        return current == receipt.movieRevision
    }

    func record(wallpaperID: UUID, sourceRevision: String, aerial: Aerial) throws {
        let receipt = Receipt(wallpaperID: wallpaperID, sourceRevision: sourceRevision,
                              movieRevision: try Self.fileRevision(aerial.videoURL))
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(receipt).write(to: file(aerial), options: .atomic)
    }

    func clear(_ aerial: Aerial) { try? FileManager.default.removeItem(at: file(aerial)) }

    private func file(_ aerial: Aerial) -> URL {
        root.appending(path: LockScreenExportCache.fingerprint(text: aerial.id) + ".json")
    }
}
