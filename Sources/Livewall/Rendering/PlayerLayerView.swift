import AppKit
import AVFoundation

/// Layer-hosting view that fills its bounds with an `AVPlayerLayer`.
final class PlayerLayerView: NSView {
    init(player: AVPlayer) {
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = NSColor.black.cgColor
        super.init(frame: .zero)
        layer = playerLayer
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
