import AppKit
import Testing
@testable import Livewall

@MainActor
@Suite struct WorkshopThumbnailsTests {
    @Test func initializesWithConfiguredCountLimit() {
        let thumbnails = WorkshopThumbnails(countLimit: 90)
        #expect(thumbnails.countLimit == 90)
    }

    @Test func returnsNilForInvalidURL() async {
        let thumbnails = WorkshopThumbnails()
        #expect(await thumbnails.image(for: nil) == nil)
        #expect(await thumbnails.image(for: URL(string: "ftp://example.com/test.jpg")) == nil)
        #expect(await thumbnails.image(for: URL(string: "file:///nonexistent/image.jpg")) == nil)
    }

    @Test func clearRemovesCachedObjects() async throws {
        let thumbnails = WorkshopThumbnails(countLimit: 90)
        let sampleURL = URL(string: "https://example.com/sample.jpg")!

        #expect(thumbnails.cachedImage(for: sampleURL) == nil)
        thumbnails.clear()
        #expect(thumbnails.cachedImage(for: sampleURL) == nil)
    }
}
