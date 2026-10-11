import AVFoundation
import VideoToolbox

/// Encodes a movie the way Apple ships Aerials, which the system's Aerial player needs to slow down on lock:
/// 3840×2160 HEVC Main10, 240 fps, sRGB transfer and HEVC temporal sub-layers, as one continuous segment.
///
/// Without temporal sub-layers the player fails with `VideoSampleReadingErrors` code 4 when it ramps down
/// and the lock screen turns black. The source is held frame-by-frame up to 240 fps and looped until the movie
/// covers `minimumDuration` (the original's length, so every "point of interest" the player resumes at has frames).
final class AerialMovieEncoder {
    struct Format {
        var width = 3840
        var height = 2160
        var frameDuration = CMTime(value: 1001, timescale: 240_000)
        var bitRate = 12_000_000
        var temporalLayers = 4
        var baseLayerFrameRate = 30
    }

    private let format: Format

    init(format: Format = Format()) {
        self.format = format
    }

    static func duration(of url: URL) async -> CMTime {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let range = try? await track.load(.timeRange)
        else { return .zero }
        return range.duration
    }

    func encode(_ source: URL, minimumDuration: CMTime, to output: URL, progress: @escaping (Double) -> Void) async throws {
        let asset = AVURLAsset(url: source)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw LockScreenError.noVideoTrack }
        let loopLength = try await track.load(.timeRange).duration.seconds
        guard loopLength > 0 else { throw LockScreenError.noVideoTrack }

        let loops = max(1, Int((minimumDuration.seconds / loopLength).rounded(.up)))
        let tick = format.frameDuration.seconds
        let totalFrames = Int((Double(loops) * loopLength / tick).rounded(.down))
        let composition = try await fillComposition(for: asset, track: track)
        let session = try makeSession()
        defer { VTCompressionSessionInvalidate(session) }
        let collector = EncodedSampleCollector()

        var frame = 0
        for loop in 0..<loops {
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderVideoCompositionOutput(videoTracks: [track], videoSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
            ])
            output.videoComposition = composition
            reader.add(output)
            guard reader.startReading() else {
                throw LockScreenError.encodingFailed(reader.error?.localizedDescription ?? "no se pudo leer el video")
            }

            guard var current = output.copyNextSampleBuffer() else { throw LockScreenError.noVideoTrack }
            var next = output.copyNextSampleBuffer()
            let loopStart = Double(loop) * loopLength

            // Sample-and-hold: every 240 fps tick shows the latest source frame at or before that time.
            while frame < totalFrames, Double(frame) * tick - loopStart < loopLength {
                let local = Double(frame) * tick - loopStart
                while let candidate = next, CMSampleBufferGetPresentationTimeStamp(candidate).seconds <= local {
                    current = candidate
                    next = output.copyNextSampleBuffer()
                }
                guard let pixels = CMSampleBufferGetImageBuffer(current) else { throw LockScreenError.noVideoTrack }
                try await encodeFrame(pixels, index: frame, session: session, collector: collector)
                frame += 1
                if frame % 240 == 0 {
                    progress(Double(frame) / Double(totalFrames) * 0.95)
                }
            }
            reader.cancelReading()
        }

        VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
        if let error = collector.error { throw error }
        try await write(collector.samples, to: output)
        progress(1)
    }

    private func encodeFrame(_ pixels: CVImageBuffer, index: Int, session: VTCompressionSession,
                             collector: EncodedSampleCollector) async throws {
        // Keep the encoder's queue short so decoded 4K frames are not piling up in memory.
        while pendingFrameCount(session) > 8 {
            try await Task.sleep(for: .milliseconds(1))
        }
        let pts = CMTimeMultiply(format.frameDuration, multiplier: Int32(index))
        let status = VTCompressionSessionEncodeFrame(
            session, imageBuffer: pixels, presentationTimeStamp: pts, duration: format.frameDuration,
            frameProperties: nil, infoFlagsOut: nil
        ) { status, _, sample in
            collector.receive(status: status, sample: sample)
        }
        guard status == noErr else { throw LockScreenError.encodingFailed("VideoToolbox \(status)") }
    }

    private func pendingFrameCount(_ session: VTCompressionSession) -> Int {
        var value: CFTypeRef?
        VTSessionCopyProperty(session, key: kVTCompressionPropertyKey_NumberOfPendingFrames, allocator: nil, valueOut: &value)
        return (value as? NSNumber)?.intValue ?? 0
    }

    private func makeSession() throws -> VTCompressionSession {
        var created: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: nil, width: Int32(format.width), height: Int32(format.height), codecType: kCMVideoCodecType_HEVC,
            encoderSpecification: [kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder: true] as CFDictionary,
            imageBufferAttributes: nil, compressedDataAllocator: nil, outputCallback: nil, refcon: nil,
            compressionSessionOut: &created
        )
        guard status == noErr, let session = created else {
            throw LockScreenError.encodingFailed("no hay codificador HEVC por hardware (\(status))")
        }

        let properties: [(CFString, CFTypeRef)] = [
            (kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_HEVC_Main10_AutoLevel),
            (kVTCompressionPropertyKey_RealTime, kCFBooleanFalse),
            (kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanTrue),
            (kVTCompressionPropertyKey_ExpectedFrameRate, NSNumber(value: 1 / format.frameDuration.seconds)),
            (kVTCompressionPropertyKey_AverageBitRate, NSNumber(value: format.bitRate)),
            (kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, NSNumber(value: 1)),
            (kVTCompressionPropertyKey_ColorPrimaries, kCVImageBufferColorPrimaries_ITU_R_709_2),
            (kVTCompressionPropertyKey_TransferFunction, kCVImageBufferTransferFunction_sRGB),
            (kVTCompressionPropertyKey_YCbCrMatrix, kCVImageBufferYCbCrMatrix_ITU_R_709_2),
            // Not exported as constants, but listed by VTSessionCopySupportedPropertyDictionary on Apple silicon.
            ("NumberOfTemporalLayers" as CFString, NSNumber(value: format.temporalLayers)),
            (kVTCompressionPropertyKey_BaseLayerFrameRate, NSNumber(value: format.baseLayerFrameRate)),
            ("TemporalIDNestingFlag" as CFString, kCFBooleanTrue),
        ]
        for (key, value) in properties {
            let status = VTSessionSetProperty(session, key: key, value: value)
            guard status == noErr else {
                VTCompressionSessionInvalidate(session)
                throw LockScreenError.encodingFailed("el codificador no acepta \(key) (\(status))")
            }
        }
        VTCompressionSessionPrepareToEncodeFrames(session)
        return session
    }

    /// Scales and crops the source to fill the output frame, honoring its rotation.
    private func fillComposition(for asset: AVAsset, track: AVAssetTrack) async throws -> AVVideoComposition {
        let natural = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let oriented = CGRect(origin: .zero, size: natural).applying(transform)
        let width = CGFloat(format.width), height = CGFloat(format.height)
        let scale = max(width / abs(oriented.width), height / abs(oriented.height))

        let fill = transform
            .concatenating(CGAffineTransform(translationX: -oriented.minX, y: -oriented.minY))
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(
                translationX: (width - abs(oriented.width) * scale) / 2,
                y: (height - abs(oriented.height) * scale) / 2
            ))

        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        layer.setTransform(fill, at: .zero)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: try await asset.load(.duration))
        instruction.layerInstructions = [layer]

        let composition = AVMutableVideoComposition()
        composition.renderSize = CGSize(width: width, height: height)
        let minFrame = try await track.load(.minFrameDuration)
        composition.frameDuration = minFrame.isValid && minFrame.seconds > 0 ? minFrame : CMTime(value: 1, timescale: 60)
        composition.instructions = [instruction]
        return composition
    }

    private func write(_ samples: [CMSampleBuffer], to url: URL) async throws {
        guard let first = samples.first, let hint = CMSampleBufferGetFormatDescription(first) else {
            throw LockScreenError.encodingFailed("el codificador no produjo cuadros")
        }
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: nil, sourceFormatHint: hint)
        input.mediaTimeScale = format.frameDuration.timescale
        input.expectsMediaDataInRealTime = false
        writer.add(input)
        guard writer.startWriting() else {
            throw LockScreenError.encodingFailed(writer.error?.localizedDescription ?? "no se pudo escribir")
        }
        writer.startSession(atSourceTime: .zero)
        for sample in samples {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(1))
            }
            guard input.append(sample) else {
                throw LockScreenError.encodingFailed(writer.error?.localizedDescription ?? "no se pudo escribir un cuadro")
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw LockScreenError.encodingFailed(writer.error?.localizedDescription ?? "no se pudo cerrar el archivo")
        }
    }
}
