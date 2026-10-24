import AppKit
import AVFoundation
import Testing
@testable import Livewall

@MainActor
@Suite struct RendererOptionsTests {
    @Test func changingMuteKeepsVideoPlayer() throws {
        let renderer = VideoRenderer(url: URL(fileURLWithPath: "/tmp/livewall-missing-test.mov"),
                                     options: RenderOptions(muted: true, frameRate: 60))
        defer { renderer.tearDown() }
        let layer = try #require(renderer.view.layer as? AVPlayerLayer)
        let player = try #require(layer.player)
        #expect(player.isMuted)
        renderer.update(options: RenderOptions(muted: false, frameRate: 30))
        #expect(layer.player === player)
        #expect(!player.isMuted)
        renderer.update(options: RenderOptions(muted: true, frameRate: 120))
        #expect(layer.player === player)
        #expect(player.isMuted)
    }
}
