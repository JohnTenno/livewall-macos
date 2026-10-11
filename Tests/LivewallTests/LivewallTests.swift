import Foundation
import Testing
@testable import Livewall

@Suite struct WallpaperKindTests {
    @Test func infersKindFromExtension() {
        #expect(WallpaperKind(fileExtension: "MP4") == .video)
        #expect(WallpaperKind(fileExtension: "html") == .web)
        #expect(WallpaperKind(fileExtension: "metal") == .shader)
        #expect(WallpaperKind(fileExtension: "png") == nil)
    }
}

@Suite struct ShaderTests {
    @Test func builtInShadersCompile() throws {
        for wallpaper in BuiltInShaders.wallpapers {
            guard case .builtInShader(let key) = wallpaper.source, let source = BuiltInShaders.source(forKey: key) else {
                Issue.record("Missing source for \(wallpaper.name)")
                continue
            }
            _ = try ShaderPipeline(userSource: source)
        }
    }

    @Test func invalidShaderReportsCompileError() {
        #expect(throws: ShaderError.self) {
            try ShaderPipeline(userSource: "float4 wallpaper(float2 a) { return nope; }")
        }
    }
}

@MainActor
@Suite struct WallpaperLibraryTests {
    private func makeLibrary() -> (WallpaperLibrary, URL) {
        let root = FileManager.default.temporaryDirectory.appending(path: "livewall-tests-\(UUID().uuidString)")
        return (WallpaperLibrary(rootURL: root), root)
    }

    @Test func importsFilePersistsAndRemoves() throws {
        let (library, root) = makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        let shader = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).metal")
        try "// test".write(to: shader, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: shader) }

        let wallpaper = try library.importItem(at: shader)
        #expect(wallpaper.kind == .shader)
        guard case .libraryFile(let path) = wallpaper.source else { Issue.record("Expected a library file"); return }
        #expect(FileManager.default.fileExists(atPath: library.fileURL(forRelativePath: path).path))

        #expect(WallpaperLibrary(rootURL: root).userWallpapers == [wallpaper])

        library.remove(wallpaper)
        #expect(!FileManager.default.fileExists(atPath: library.fileURL(forRelativePath: path).path))
        #expect(WallpaperLibrary(rootURL: root).userWallpapers.isEmpty)
    }

    @Test func importsWebFolderWithIndex() throws {
        let (library, root) = makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }

        let folder = FileManager.default.temporaryDirectory.appending(path: "site-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(throws: LibraryError.self) { try library.importItem(at: folder) }

        try "<h1>hi</h1>".write(to: folder.appending(path: "index.html"), atomically: true, encoding: .utf8)
        let wallpaper = try library.importItem(at: folder)
        #expect(wallpaper.kind == .web)
    }

    @Test func rejectsInvalidWebsite() {
        let (library, root) = makeLibrary()
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(throws: LibraryError.self) { try library.addWebsite("ftp://x", name: "") }
        #expect(throws: LibraryError.self) { try library.addWebsite("https://", name: "") }
    }
}
