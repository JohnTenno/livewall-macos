import Foundation
import Testing
@testable import Livewall

@Suite struct WorkshopAPITests {
    @Test func decodesQueryFilesResponse() throws {
        let json = """
        {"response":{"total":2,"next_cursor":"AoJ4","publishedfiledetails":[
          {"publishedfileid":"123","title":"Rain","preview_url":"https://x.test/p.jpg","file_size":"1048576",
           "subscriptions":42,"tags":[{"tag":"Video","display_name":"Video"},{"tag":"Everyone","display_name":"Everyone"}],
           "short_description":"wet"},
          {"publishedfileid":"456","title":"Castle","file_size":"10","tags":[{"tag":"Scene"}]}
        ]}}
        """
        let page = try WorkshopPage.decode(Data(json.utf8))
        #expect(page.total == 2)
        #expect(page.nextCursor == "AoJ4")
        #expect(page.items.map(\.id) == ["123", "456"])
        #expect(page.items[0].fileSize == 1_048_576)
        #expect(page.items[0].type == .video)
        #expect(page.items[1].type == .scene)
        #expect(page.items[1].type?.isSupported == false)
    }

    @Test func decodesResolutionAndYouTubePreview() throws {
        let json = """
        {"response":{"total":1,"publishedfiledetails":[
          {"publishedfileid":"999","title":"Neon City","file_size":"2048",
           "tags":[{"tag":"Video"},{"tag":"3840 x 2160"},{"tag":"Cyberpunk"},{"tag":"Everyone"}],
           "previews":[{"preview_type":1,"youtubevideoid":"xyz123"}]}
        ]}}
        """
        let page = try WorkshopPage.decode(Data(json.utf8))
        let item = try #require(page.items.first)
        #expect(item.resolution == "3840 × 2160")
        #expect(item.youTubeVideoID == "xyz123")
        #expect(item.categoryTags == ["Cyberpunk"])
    }

    @Test func decodesEmptyResponse() throws {
        let page = try WorkshopPage.decode(Data(#"{"response":{"total":0}}"#.utf8))
        #expect(page.items.isEmpty)
    }

    @Test func buildsQueryURL() throws {
        var query = WorkshopQuery()
        query.text = "  rain "
        let url = query.url(apiKey: "KEY", cursor: "*")
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let values = Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
        #expect(values["appid"] == "431960")
        #expect(values["query_type"] == "12")
        #expect(values["search_text"] == "rain")
        #expect(values["requiredtags[0]"] == "Video")
        #expect(values["requiredtags[1]"] == "Web")
        #expect(values["excludedtags[0]"] == "Mature")

        query.text = ""
        query.type = .web
        query.includeMature = true
        let names = URLComponents(url: query.url(apiKey: "KEY", cursor: "*"), resolvingAgainstBaseURL: false)!.queryItems!.map(\.name)
        #expect(!names.contains("search_text"))
        #expect(!names.contains("requiredtags[1]"))
        #expect(!names.contains("excludedtags[0]"))
    }
}

@Suite struct SteamCMDTests {
    @Test func parsesSuccessfulDownload() throws {
        let output = """
        Logging in user 'me' to Steam Public...OK
        Downloading item 123 ...
        Success. Downloaded item 123 to "/Users/me/Library/Application Support/Steam/steamapps/workshop/content/431960/123" (1048576 bytes)
        """
        let folder = try SteamCMD.parseDownloadOutput(output, itemID: "123")
        #expect(folder.path == "/Users/me/Library/Application Support/Steam/steamapps/workshop/content/431960/123")
    }

    @Test func detectsMissingSession() {
        let output = "Logging in user 'me' to Steam Public...\nCached credentials not found.\nFAILED (No Connection)"
        #expect(throws: WorkshopError.self) { try SteamCMD.parseDownloadOutput(output, itemID: "123") }
    }

    @Test func installsFromArchive() async throws {
        let tmp = FileManager.default.temporaryDirectory.appending(path: "steamcmd-test-\(UUID())")
        let srcDir = tmp.appending(path: "src")
        let destDir = tmp.appending(path: "dest")
        let archiveURL = tmp.appending(path: "test.tar.gz")
        defer { try? FileManager.default.removeItem(at: tmp) }

        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        let dummyScript = srcDir.appending(path: "steamcmd.sh")
        try "#!/bin/sh\nexit 0\n".write(to: dummyScript, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dummyScript.path)

        let tar = Process()
        tar.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        tar.arguments = ["-czf", archiveURL.path, "-C", srcDir.path, "steamcmd.sh"]
        try tar.run()
        tar.waitUntilExit()

        let steamCMD = SteamCMD(root: destDir)
        #expect(!steamCMD.isInstalled)
        try await steamCMD.install(from: archiveURL)
        #expect(steamCMD.isInstalled)
    }
}

@MainActor
@Suite struct WorkshopImporterTests {
    private func makeItem(_ project: String, files: [String: String]) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "we-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try project.write(to: folder.appending(path: "project.json"), atomically: true, encoding: .utf8)
        for (name, contents) in files {
            try contents.write(to: folder.appending(path: name), atomically: true, encoding: .utf8)
        }
        return folder
    }

    @Test func importsVideoAndWebProjects() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "lib-\(UUID().uuidString)")
        let library = WallpaperLibrary(rootURL: root)
        let importer = WorkshopImporter(library: library)
        defer { try? FileManager.default.removeItem(at: root) }

        let video = try makeItem(#"{"title":"Rain","type":"video","file":"rain.mp4"}"#, files: ["rain.mp4": "x"])
        let web = try makeItem(
            #"{"title":"Clock","type":"Web","file":"main.html","general":{"properties":{"color":{"value":"1 0 0"},"speed":{"value":3}}}}"#,
            files: ["main.html": "<p>hi</p>"]
        )
        let scene = try makeItem(#"{"title":"Castle","type":"scene","file":"scene.json"}"#, files: [:])
        defer { [video, web, scene].forEach { try? FileManager.default.removeItem(at: $0) } }

        let videoWallpaper = try importer.importItem(at: video, fallbackTitle: "?")
        #expect(videoWallpaper.kind == .video)
        #expect(videoWallpaper.name == "Rain")

        let webWallpaper = try importer.importItem(at: web, fallbackTitle: "?")
        #expect(webWallpaper.kind == .web)
        guard case .libraryFile(let path) = webWallpaper.source else { Issue.record("Expected library file"); return }
        #expect(path.hasSuffix("/main.html"))
        let copiedProject = try WallpaperEngineProject.load(from: library.fileURL(forRelativePath: path).deletingLastPathComponent())
        #expect(copiedProject.defaultPropertiesJSON().contains(#""speed":{"value":3}"#))

        #expect(throws: WorkshopError.self) { try importer.importItem(at: scene, fallbackTitle: "?") }
    }
}
