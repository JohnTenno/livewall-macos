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

    @Test func decodesEmptyResponse() throws {
        let page = try WorkshopPage.decode(Data(#"{"response":{"total":0}}"#.utf8))
        #expect(page.items.isEmpty)
    }

    @Test func emptyLaterPageDoesNotTurnLoadedResultsIntoZeroTotal() throws {
        let page = try WorkshopPage.decode(Data(#"{"response":{"total":0}}"#.utf8))
        #expect(page.resolvedTotal(previous: 1_200_000, loadedCount: 120) == 1_200_000)
        #expect(page.resolvedTotal(previous: nil, loadedCount: 120) == nil)
        #expect(page.resolvedTotal(previous: nil, loadedCount: 0) == 0)
    }

    @Test func decodesStringTotalsAndKeepsUnknownTotalsUnknown() throws {
        let stringTotal = try WorkshopPage.decode(Data(#"{"response":{"total":"1234","publishedfiledetails":[]}}"#.utf8))
        #expect(stringTotal.total == 1234)
        let unknown = try WorkshopPage.decode(Data(#"{"response":{"publishedfiledetails":[{"publishedfileid":"1","title":"Test"}],"next_cursor":"next"}}"#.utf8))
        #expect(unknown.total == nil)
        #expect(unknown.items.count == 1)
        #expect(unknown.resolvedTotal(previous: nil, loadedCount: 30) == nil)
        #expect(throws: DecodingError.self) {
            try WorkshopPage.decode(Data(#"{"response":{"error":"Invalid request"}}"#.utf8))
        }
    }

    @Test func encodesPlusSignsInCursorsAndText() {
        var query = WorkshopQuery()
        query.text = "c++"
        let url = query.url(apiKey: "KEY", cursor: "AoIIQypE/H+Anq5h").absoluteString
        #expect(url.contains("cursor=AoIIQypE/H%2BAnq5h"))
        #expect(url.contains("search_text=c%2B%2B"))
        #expect(!url.contains("+"))
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
        #expect(values["return_previews"] == "true")
        #expect(values["match_all_tags"] == "true")
        #expect(values["requiredtags[0]"] == nil)
        // "Video or web" and "Everyone only" are expressed as exclusions.
        #expect(Set(items.filter { $0.name.hasPrefix("excludedtags") }.map(\.value)) == ["Scene", "Application", "Questionable", "Mature"])
        #expect(values["days"] == nil, "text search has no period")

        query.text = ""
        query.filters.type = .web
        query.filters.ratings = Set(WorkshopRating.allCases)
        query.filters.category = "Anime"
        query.filters.resolution = "3840 x 2160"
        query.filters.features = ["Customizable", "Audio responsive"]
        let second = try #require(URLComponents(url: query.url(apiKey: "KEY", cursor: "*"), resolvingAgainstBaseURL: false)?.queryItems)
        #expect(!second.contains { $0.name == "search_text" })
        #expect(second.filter { $0.name.hasPrefix("requiredtags") }.map(\.value) == ["Web", "Anime", "3840 x 2160", "Audio responsive", "Customizable"])
        #expect(!second.contains { $0.name.hasPrefix("excludedtags") })
        #expect(second.first { $0.name == "days" }?.value == "7")
        #expect(query.filters.activeCount == 6)

        query.period = .allTime
        #expect(!URLComponents(url: query.url(apiKey: "KEY", cursor: "*"), resolvingAgainstBaseURL: false)!.queryItems!.contains { $0.name == "days" })
    }

    @Test func decodesAdditionalYouTubePreviewFromSteam() throws {
        let json = #"{"publishedfileid":"2250845956","title":"Preview test","previews":[{"previewid":"20844236","sortorder":1,"youtubevideoid":"Zj0CO5K5qdQ","preview_type":1,"external_reference":""}]}"#
        let item = try JSONDecoder().decode(WorkshopItem.self, from: Data(json.utf8))
        #expect(item.youtubePreviewID == "Zj0CO5K5qdQ")
        let invalid = #"{"publishedfileid":"1","previews":[{"preview_type":1,"youtubevideoid":"<script>bad</script>"}]}"#
        #expect(try JSONDecoder().decode(WorkshopItem.self, from: Data(invalid.utf8)).youtubePreviewID == nil)
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
