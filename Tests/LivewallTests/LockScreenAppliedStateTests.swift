import Foundation
import Testing
@testable import Livewall

@Suite struct LockScreenAppliedStateTests {
    @Test func persistsAndDistinguishesWallpaperSourceAndAerial() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "applied-test-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let aerial = Aerial(id: "test", name: "Test", videoURL: root.appending(path: "installed.mov"))
        try Data("movie".utf8).write(to: aerial.videoURL)
        let id = UUID(), state = LockScreenAppliedState(libraryRoot: root)
        #expect(!state.isApplied(wallpaperID: id, sourceRevision: "v1", aerial: aerial))
        try state.record(wallpaperID: id, sourceRevision: "v1", aerial: aerial)
        let reopened = LockScreenAppliedState(libraryRoot: root)
        #expect(reopened.isApplied(wallpaperID: id, sourceRevision: "v1", aerial: aerial))
        #expect(!reopened.isApplied(wallpaperID: UUID(), sourceRevision: "v1", aerial: aerial))
        #expect(!reopened.isApplied(wallpaperID: id, sourceRevision: "v2", aerial: aerial))
        let other = Aerial(id: "other", name: "Other", videoURL: aerial.videoURL)
        #expect(!reopened.isApplied(wallpaperID: id, sourceRevision: "v1", aerial: other))
        state.clear(aerial)
        #expect(!reopened.isApplied(wallpaperID: id, sourceRevision: "v1", aerial: aerial))
    }

    @Test func replacedOrDeletedInstalledMovieReenablesApply() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "applied-test-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let aerial = Aerial(id: "test", name: "Test", videoURL: root.appending(path: "installed.mov"))
        try Data("movie".utf8).write(to: aerial.videoURL)
        let state = LockScreenAppliedState(libraryRoot: root), id = UUID()
        try state.record(wallpaperID: id, sourceRevision: "v1", aerial: aerial)
        try Data("apple original".utf8).write(to: aerial.videoURL, options: .atomic)
        #expect(!state.isApplied(wallpaperID: id, sourceRevision: "v1", aerial: aerial))
        try state.record(wallpaperID: id, sourceRevision: "v1", aerial: aerial)
        try FileManager.default.removeItem(at: aerial.videoURL)
        #expect(!state.isApplied(wallpaperID: id, sourceRevision: "v1", aerial: aerial))
    }
}
