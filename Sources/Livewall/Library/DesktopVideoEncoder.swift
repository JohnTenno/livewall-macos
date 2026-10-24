import AVFoundation
import VideoToolbox

/// Re-encodes a video to a display-sized HEVC copy for desktop playback (hardware encoder).
final class DesktopVideoEncoder {
    /// Reads the oriented size and frame rate that `DesktopVariantPlan` needs.
    static func probe(_ source: URL) async throws -> (size: CGSize, frameRate: Double) {
        guard let track = try await AVURLAsset(url: source).loadTracks(withMediaType: .video).first else {
            throw DesktopVideoError.failed("The file has no video track")
        }
        let (size, transform, fps) = try await track.load(.naturalSize, .preferredTransform, .nominalFrameRate)
        let oriented = CGRect(origin: .zero, size: size).applying(transform)
        return (CGSize(width: abs(oriented.width), height: abs(oriented.height)), Double(fps))
    }

    func encode(source: URL, destination: URL, size target: CGSize, frameRate: Int,
                progress: @escaping @Sendable (Double) -> Void) async throws {
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw DesktopVideoError.failed("Output already exists: \(destination.path)")
        }
        let asset = AVURLAsset(url: source)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw DesktopVideoError.failed("Source has no video track")
        }
        let duration = try await asset.load(.duration)
        let size = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let oriented = CGRect(origin: .zero, size: size).applying(transform)
        let width = target.width, height = target.height
        let scale = max(width / abs(oriented.width), height / abs(oriented.height))
        let fill = transform
            .concatenating(CGAffineTransform(translationX: -oriented.minX, y: -oriented.minY))
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: (width - abs(oriented.width) * scale) / 2,
                                            y: (height - abs(oriented.height) * scale) / 2))
        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        layer.setTransform(fill, at: .zero)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        instruction.layerInstructions = [layer]
        let composition = AVMutableVideoComposition()
        composition.renderSize = CGSize(width: width, height: height)
        composition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        composition.instructions = [instruction]

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderVideoCompositionOutput(videoTracks: [track], videoSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
        ])
        output.videoComposition = composition
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw DesktopVideoError.failed("Cannot configure video reader") }
        reader.add(output)

        let staging = destination.deletingLastPathComponent().appending(path: ".encoding-\(UUID()).mov")
        defer { try? FileManager.default.removeItem(at: staging) }
        let writer = try AVAssetWriter(outputURL: staging, fileType: .mov)
        var settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: Int(width), AVVideoHeightKey: Int(height),
            AVVideoEncoderSpecificationKey: [kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder as String: true],
            AVVideoCompressionPropertiesKey: [
                // 0.1 bits per pixel per frame: visually lossless HEVC for a wallpaper (~35 Mbps at 3200×1800 60 fps).
                AVVideoAverageBitRateKey: Int(width * height * Double(frameRate) * 0.1),
                AVVideoExpectedSourceFrameRateKey: frameRate,
                AVVideoMaxKeyFrameIntervalDurationKey: 2,
                AVVideoAllowFrameReorderingKey: true,
            ],
        ]
        if let format = try await track.load(.formatDescriptions).first {
            let extensions = (CMFormatDescriptionGetExtensions(format) as NSDictionary?) ?? [:]
            var color: [String: Any] = [:]
            for (sourceKey, targetKey) in [
                (kCMFormatDescriptionExtension_ColorPrimaries, AVVideoColorPrimariesKey),
                (kCMFormatDescriptionExtension_TransferFunction, AVVideoTransferFunctionKey),
                (kCMFormatDescriptionExtension_YCbCrMatrix, AVVideoYCbCrMatrixKey),
            ] {
                if let value = extensions[sourceKey] { color[targetKey] = value }
            }
            if !color.isEmpty { settings[AVVideoColorPropertiesKey] = color }
        }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        guard writer.canApply(outputSettings: settings, forMediaType: .video), writer.canAdd(input) else {
            throw DesktopVideoError.failed("Hardware HEVC writer configuration unavailable")
        }
        writer.add(input)

        // Preserve the first audio track by passthrough; wallpaper playback is normally muted.
        var audioReader: AVAssetReader?
        var audioOutput: AVAssetReaderTrackOutput?
        var audioInput: AVAssetWriterInput?
        if let audio = try await asset.loadTracks(withMediaType: .audio).first {
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: audio, outputSettings: nil)
            let hint = try await audio.load(.formatDescriptions).first
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: nil, sourceFormatHint: hint)
            input.expectsMediaDataInRealTime = false
            guard reader.canAdd(output), writer.canAdd(input) else {
                throw DesktopVideoError.failed("Cannot preserve source audio")
            }
            reader.add(output)
            writer.add(input)
            audioReader = reader; audioOutput = output; audioInput = input
        }
        guard writer.startWriting() else { throw writer.error ?? DesktopVideoError.failed("Hardware writer did not start") }
        writer.startSession(atSourceTime: .zero)
        defer {
            reader.cancelReading()
            audioReader?.cancelReading()
            if writer.status == .writing { writer.cancelWriting() }
        }
        guard reader.startReading() else { throw reader.error ?? DesktopVideoError.failed("Video reader did not start") }
        if let audioReader, !audioReader.startReading() {
            throw audioReader.error ?? DesktopVideoError.failed("Audio reader did not start")
        }
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await self.pump(reader: audioReader, output: audioOutput, input: audioInput,
                                    writer: writer, duration: nil, progress: nil)
            }
            group.addTask {
                try await self.pump(reader: reader, output: output, input: input,
                                    writer: writer, duration: duration.seconds, progress: progress)
            }
            while let _ = try await group.next() { }
        }
        writer.endSession(atSourceTime: duration)
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? DesktopVideoError.failed("Writer failed") }
        try await verify(staging, size: target, frameRate: frameRate, duration: duration.seconds)
        try FileManager.default.moveItem(at: staging, to: destination)
    }

    private func pump(reader: AVAssetReader?, output: AVAssetReaderOutput?, input: AVAssetWriterInput?,
                      writer: AVAssetWriter, duration: Double?, progress: (@Sendable (Double) -> Void)?) async throws {
        guard let reader, let output, let input else { return }
        while true {
            try Task.checkCancellation()
            while !input.isReadyForMoreMediaData {
                guard writer.status == .writing else { throw writer.error ?? DesktopVideoError.failed("Writer stopped") }
                try await Task.sleep(for: .milliseconds(2))
            }
            let timestamp: Double? = try autoreleasepool {
                guard let sample = output.copyNextSampleBuffer() else { return nil }
                guard input.append(sample) else { throw writer.error ?? DesktopVideoError.failed("Append failed") }
                return CMSampleBufferGetPresentationTimeStamp(sample).seconds
            }
            guard let timestamp else { break }
            if let duration, duration > 0 { progress?(min(1, timestamp / duration)) }
        }
        guard reader.status == .completed else { throw reader.error ?? DesktopVideoError.failed("Reader ended early") }
        input.markAsFinished()
    }

    private func verify(_ url: URL, size expected: CGSize, frameRate: Int, duration: Double) async throws {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first,
              let format = try await track.load(.formatDescriptions).first else {
            throw DesktopVideoError.failed("Output has no video")
        }
        let size = try await track.load(.naturalSize)
        let fps = try await track.load(.nominalFrameRate)
        let length = try await asset.load(.duration).seconds
        guard size == expected, abs(Double(fps) - Double(frameRate)) < 0.1,
              abs(length - duration) < 0.1, CMFormatDescriptionGetMediaSubType(format) == kCMVideoCodecType_HEVC else {
            throw DesktopVideoError.failed("Output verification failed: \(size), \(fps) fps, \(length) seconds")
        }
    }
}
