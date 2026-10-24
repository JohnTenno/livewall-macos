import AVFoundation
import CoreVideo
import Metal

/// Renders a wallpaper shader offscreen and encodes it as an HEVC movie.
/// The last `crossfade` seconds blend into the shader's first frame, so the movie loops seamlessly.
final class ShaderVideoRecorder {
    private let spec: VideoExportSpec
    private let pipeline: ShaderPipeline
    private let blendPipeline: ShaderPipeline
    private let commandQueue: MTLCommandQueue
    private let textureCache: CVMetalTextureCache

    init(source: String, spec: VideoExportSpec) throws {
        self.spec = spec
        pipeline = try ShaderPipeline(userSource: source)
        blendPipeline = try ShaderPipeline(userSource: source, blending: true, device: pipeline.device)
        guard let queue = pipeline.device.makeCommandQueue() else { throw ShaderError.noMetalDevice }
        commandQueue = queue

        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, pipeline.device, nil, &cache)
        guard let cache else { throw LockScreenError.encodingFailed("could not create the texture cache") }
        textureCache = cache
    }

    func record(to url: URL, progress: @escaping (Double) -> Void) async throws {
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: spec.writerSettings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: spec.width,
            kCVPixelBufferHeightKey as String: spec.height,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
        ])
        writer.add(input)
        guard writer.startWriting() else { throw failure(writer) }
        writer.startSession(atSourceTime: .zero)

        for frame in 0..<spec.frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(2))
            }
            let buffer = try makePixelBuffer(adaptor)
            try render(frame: frame, into: buffer)
            let time = CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(spec.frameRate))
            guard adaptor.append(buffer, withPresentationTime: time) else { throw failure(writer) }
            if frame % spec.frameRate == 0 {
                progress(Double(frame) / Double(spec.frameCount))
            }
        }

        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw failure(writer) }
        progress(1)
    }

    private func makePixelBuffer(_ adaptor: AVAssetWriterInputPixelBufferAdaptor) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        if let pool = adaptor.pixelBufferPool {
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        }
        guard let buffer else { throw LockScreenError.encodingFailed("no pixel buffer") }
        return buffer
    }

    private func render(frame: Int, into buffer: CVPixelBuffer) throws {
        var metalTexture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(
            nil, textureCache, buffer, nil, ShaderPipeline.pixelFormat, spec.width, spec.height, 0, &metalTexture
        )
        guard let metalTexture, let texture = CVMetalTextureGetTexture(metalTexture),
              let commandBuffer = commandQueue.makeCommandBuffer()
        else { throw LockScreenError.encodingFailed("could not prepare frame \(frame)") }

        let time = Double(frame) / Double(spec.frameRate)
        encodePass(commandBuffer, texture: texture, pipeline: pipeline, time: time, blendWeight: nil)

        let fadeStart = spec.duration - spec.crossfade
        if spec.crossfade > 0, time > fadeStart {
            // At t == duration this is exactly shader(0), the movie's first frame.
            let weight = (time - fadeStart) / spec.crossfade
            encodePass(commandBuffer, texture: texture, pipeline: blendPipeline, time: time - spec.duration, blendWeight: weight)
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    private func encodePass(_ commandBuffer: MTLCommandBuffer, texture: MTLTexture, pipeline: ShaderPipeline,
                            time: Double, blendWeight: Double?) {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = blendWeight == nil ? .clear : .load
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }

        let resolution = SIMD2(Float(spec.width), Float(spec.height))
        var uniforms = ShaderUniforms(resolution: resolution, mouse: resolution / 2, time: Float(time))
        encoder.setRenderPipelineState(pipeline.state)
        if let blendWeight {
            encoder.setBlendColor(red: 0, green: 0, blue: 0, alpha: Float(blendWeight))
        }
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<ShaderUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }

    private func failure(_ writer: AVAssetWriter) -> Error {
        LockScreenError.encodingFailed(writer.error?.localizedDescription ?? "unknown encoder error")
    }
}
