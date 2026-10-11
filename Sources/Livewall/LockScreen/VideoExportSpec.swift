import AVFoundation

/// Output format for movies installed as an Aerial. Mirrors Apple's Aerials: HEVC, 3840×2160, no audio.
struct VideoExportSpec {
    var width = 3840
    var height = 2160
    var frameRate = 60
    var duration: Double = 30
    /// Seconds at the end that fade into the first frame, so the system's loop has no visible jump.
    var crossfade: Double = 2
    var bitRate = 20_000_000

    static let lockScreen = VideoExportSpec()

    var frameCount: Int { Int(duration * Double(frameRate)) }

    var writerSettings: [String: Any] {
        [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitRate,
                AVVideoExpectedSourceFrameRateKey: frameRate,
            ],
        ]
    }
}
