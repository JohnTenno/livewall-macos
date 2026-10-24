import Foundation
import Testing
@testable import Livewall

@Suite struct LockScreenExportCacheTests {
    private func root() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "export-cache-test-\(UUID())")
    }

    @Test func reusesAcrossInstancesAndRegeneratesAfterDeletion() async throws {
        let root = root(), id = UUID()
        defer { try? FileManager.default.removeItem(at: root) }
        var calls = 0
        let produce: (URL) async throws -> Void = { url in
            calls += 1
            try Data("completed movie".utf8).write(to: url)
        }
        let cache = LockScreenExportCache(libraryRoot: root)
        let first = try await cache.resolve(wallpaperID: id, key: "recipe", produce: produce)
        let second = try await LockScreenExportCache(libraryRoot: root).resolve(wallpaperID: id, key: "recipe", produce: produce)
        #expect(first == second)
        #expect(calls == 1)
        try FileManager.default.removeItem(at: first)
        _ = try await cache.resolve(wallpaperID: id, key: "recipe", produce: produce)
        #expect(calls == 2)
    }

    @Test func incompleteAndEmptyExportsAreNotReused() async throws {
        let root = root(), id = UUID()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = LockScreenExportCache(libraryRoot: root)
        do {
            _ = try await cache.resolve(wallpaperID: id, key: "recipe") { url in
                try Data("partial".utf8).write(to: url)
                throw CancellationError()
            }
            Issue.record("Expected failed producer")
        } catch is CancellationError { }
        #expect(cache.movie(wallpaperID: id, key: "recipe") == nil)
        let folder = root.appending(path: "LockScreenExports/\(id.uuidString)")
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
        let movie = try await cache.resolve(wallpaperID: id, key: "recipe") { url in
            try Data("complete".utf8).write(to: url)
        }
        try Data().write(to: movie)
        #expect(cache.movie(wallpaperID: id, key: "recipe") == nil)
        _ = try await cache.resolve(wallpaperID: id, key: "recipe") { url in
            try Data("regenerated".utf8).write(to: url)
        }
        #expect(try String(contentsOf: movie, encoding: .utf8) == "regenerated")
    }

    @Test func contentAndRecipeChangesInvalidateKey() throws {
        let root = root()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appending(path: "video.mov")
        try Data("first".utf8).write(to: source)
        let first = try LockScreenExportCache.fingerprint(file: source)
        try Data("other".utf8).write(to: source) // Same length; content still invalidates.
        let second = try LockScreenExportCache.fingerprint(file: source)
        #expect(first != second)
        let spec = VideoExportSpec.lockScreen
        let key = LockScreenExportCache.key(source: first, minimumDuration: 60, spec: spec)
        #expect(key != LockScreenExportCache.key(source: second, minimumDuration: 60, spec: spec))
        #expect(key != LockScreenExportCache.key(source: first, minimumDuration: 120, spec: spec))
        var changed = spec
        changed.frameRate = 30
        #expect(key != LockScreenExportCache.key(source: first, minimumDuration: 60, spec: changed))
        changed = spec
        changed.crossfade = 0
        #expect(key != LockScreenExportCache.key(source: first, minimumDuration: 60, spec: changed))
    }

    @MainActor @Test func deletingWallpaperRemovesOnlyItsExports() async throws {
        let root = root()
        defer { try? FileManager.default.removeItem(at: root) }
        let library = WallpaperLibrary(rootURL: root)
        let source = root.appending(path: "source.mov")
        try Data("video".utf8).write(to: source)
        let wallpaper = try library.importItem(at: source)
        let other = UUID()
        let cache = LockScreenExportCache(libraryRoot: root)
        for id in [wallpaper.id, other] {
            _ = try await cache.resolve(wallpaperID: id, key: "recipe") { url in
                try Data("export".utf8).write(to: url)
            }
        }
        library.remove(wallpaper)
        #expect(cache.movie(wallpaperID: wallpaper.id, key: "recipe") == nil)
        #expect(cache.movie(wallpaperID: other, key: "recipe") != nil)
    }
}
