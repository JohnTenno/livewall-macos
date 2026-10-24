import AppKit
import AVFoundation

/// Plays a video file in a seamless loop.
@MainActor
final class VideoRenderer: WallpaperRenderer {
    let view: NSView
    private let player: AVQueuePlayer
    private let looper: AVPlayerLooper

    init(url: URL, options: RenderOptions) {
        player = AVQueuePlayer()
        player.isMuted = options.muted
        player.preventsDisplaySleepDuringVideoPlayback = false
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        view = PlayerLayerView(player: player)
    }

    func update(options: RenderOptions) { player.isMuted = options.muted }

    func play() { player.play() }

    func pause() { player.pause() }

    func tearDown() {
        player.pause()
        looper.disableLooping()
        player.removeAllItems()
    }
}
