import AVFoundation

/// Re-encodes a video wallpaper as a silent 4K HEVC movie, the format Aerials use.
final class VideoTranscoder {
    func transcode(_ source: URL, to destination: URL) async throws {
        let asset = AVURLAsset(url: source)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw LockScreenError.noVideoTrack
        }

        // Copy only the video track: Aerials have no audio.
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw LockScreenError.encodingFailed("no se pudo crear la composición")
        }
        let duration = try await asset.load(.duration)
        try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: track, at: .zero)
        videoTrack.preferredTransform = try await track.load(.preferredTransform)

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHEVC3840x2160) else {
            throw LockScreenError.encodingFailed("HEVC 4K no está disponible")
        }
        try? FileManager.default.removeItem(at: destination)
        try await session.export(to: destination, as: .mov)
    }
}
