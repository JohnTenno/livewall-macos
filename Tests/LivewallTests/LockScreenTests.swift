import AVFoundation
import Foundation
import Testing
@testable import Livewall

@Suite struct ShaderVideoRecorderTests {
    @Test func recordsShortHEVCMovie() async throws {
        let spec = VideoExportSpec(width: 320, height: 180, frameRate: 15, duration: 2, crossfade: 0.5, bitRate: 500_000)
        let source = try #require(BuiltInShaders.source(forKey: "plasma"))
        let output = FileManager.default.temporaryDirectory.appending(path: "livewall-test-\(UUID().uuidString).mov")
        defer { try? FileManager.default.removeItem(at: output) }

        var lastProgress = 0.0
        try await ShaderVideoRecorder(source: source, spec: spec).record(to: output) { lastProgress = $0 }

        #expect(lastProgress == 1)
        let asset = AVURLAsset(url: output)
        let duration = try await asset.load(.duration).seconds
        #expect(abs(duration - 2) < 0.2)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let format = try #require(try await track.load(.formatDescriptions).first)
        #expect(CMFormatDescriptionGetMediaSubType(format) == kCMVideoCodecType_HEVC)
        #expect(try await track.load(.naturalSize) == CGSize(width: 320, height: 180))
    }
}

@Suite struct AerialStoreTests {
    private let assetID = "F439B0A7-D18C-4B14-9681-6520E6A74FE9"

    /// Builds a fake `com.apple.wallpaper` folder shaped like the real one.
    private func makeWallpaperRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "wallpaper-\(UUID().uuidString)")
        let fm = FileManager.default
        try fm.createDirectory(at: root.appending(path: "Store"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appending(path: "aerials/videos"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appending(path: "aerials/manifest"), withIntermediateDirectories: true)

        let configuration = try PropertyListSerialization.data(fromPropertyList: ["assetID": assetID], format: .binary, options: 0)
        let choice: [String: Any] = ["Provider": "com.apple.wallpaper.choice.aerials", "Configuration": configuration, "Files": []]
        let index: [String: Any] = ["AllSpacesAndDisplays": ["Linked": ["Content": ["Choices": [choice]]]]]
        try PropertyListSerialization.data(fromPropertyList: index, format: .binary, options: 0)
            .write(to: root.appending(path: "Store/Index.plist"))

        let manifest = #"{"assets":[{"id":"\#(assetID)","accessibilityLabel":"Iran and Afghanistan"}]}"#
        try manifest.write(to: root.appending(path: "aerials/manifest/entries.json"), atomically: true, encoding: .utf8)
        return root
    }

    @Test func installsBacksUpAndRestores() throws {
        let root = try makeWallpaperRoot()
        let backups = root.appending(path: "backups")
        defer { try? FileManager.default.removeItem(at: root) }

        var restarts = 0
        let store = AerialStore(wallpaperRoot: root, backupRoot: backups, restartServices: { restarts += 1 })
        let aerial = try #require(store.selectedAerial())
        #expect(aerial.id == assetID)
        #expect(aerial.name == "Iran and Afghanistan")
        #expect(!aerial.isDownloaded)

        try "original".write(to: aerial.videoURL, atomically: true, encoding: .utf8)
        setxattr(aerial.videoURL.path, "LastETag", "etag", 4, 0, 0)

        let movie = root.appending(path: "mine.mov")
        try "livewall".write(to: movie, atomically: true, encoding: .utf8)
        try store.install(movie, for: aerial)

        #expect(try String(contentsOf: aerial.videoURL, encoding: .utf8) == "livewall")
        #expect(getxattr(aerial.videoURL.path, "LastETag", nil, 0, 0, 0) == 4)
        #expect(store.hasBackup(for: aerial))

        // Installing again must keep the Apple original as the backup, not the previous Livewall movie.
        try store.install(movie, for: aerial)
        try store.restore(aerial)
        #expect(try String(contentsOf: aerial.videoURL, encoding: .utf8) == "original")
        #expect(!store.hasBackup(for: aerial))
        #expect(restarts == 3)
    }

    @Test func returnsNilWithoutAerialChoice() {
        let store = AerialStore(wallpaperRoot: FileManager.default.temporaryDirectory.appending(path: "missing-\(UUID())"),
                                backupRoot: FileManager.default.temporaryDirectory, restartServices: {})
        #expect(store.selectedAerial() == nil)
    }
}
