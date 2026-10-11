import AVFoundation

/// Repeats a movie back to back until it is at least a given length, without re-encoding.
///
/// The Aerial player resumes at the asset's "points of interest" (e.g. 0, 15 and 60 s). A replacement shorter than
/// the original has no frames at those times, so the lock screen freezes after the first showing.
final class MovieLooper {
    func extend(_ source: URL, toAtLeast minimum: CMTime, output: URL) async throws {
        let asset = AVURLAsset(url: source)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw LockScreenError.noVideoTrack
        }
        let length = try await track.load(.timeRange).duration
        guard length.seconds > 0 else { throw LockScreenError.noVideoTrack }

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw LockScreenError.encodingFailed("no se pudo crear la composición")
        }
        videoTrack.preferredTransform = try await track.load(.preferredTransform)

        var cursor = CMTime.zero
        repeat {
            try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: length), of: track, at: cursor)
            cursor = cursor + length
        } while cursor < minimum

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            throw LockScreenError.encodingFailed("no se pudo copiar el video")
        }
        try? FileManager.default.removeItem(at: output)
        try await session.export(to: output, as: .mov)
    }

    /// Length of a movie's video track, or zero when it cannot be read.
    static func duration(of url: URL) async -> CMTime {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let range = try? await track.load(.timeRange)
        else { return .zero }
        return range.duration
    }
}
