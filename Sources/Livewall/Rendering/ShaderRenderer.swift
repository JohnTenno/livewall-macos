import AppKit
import MetalKit

/// Draws a full-screen Metal fragment shader that receives time, resolution and the global mouse position.
@MainActor
final class ShaderRenderer: NSObject, WallpaperRenderer, MTKViewDelegate {
    let view: NSView
    private let metalView: MTKView
    private let pipeline: ShaderPipeline
    private let commandQueue: MTLCommandQueue

    /// Shader time only advances while playing, so pausing freezes the animation instead of skipping ahead.
    private var accumulatedTime: CFTimeInterval = 0
    private var resumedAt: CFTimeInterval?

    init(source: String, options: RenderOptions) throws {
        pipeline = try ShaderPipeline(userSource: source)
        guard let queue = pipeline.device.makeCommandQueue() else { throw ShaderError.noMetalDevice }
        commandQueue = queue

        metalView = MTKView(frame: .zero, device: pipeline.device)
        metalView.colorPixelFormat = ShaderPipeline.pixelFormat
        metalView.preferredFramesPerSecond = options.frameRate
        metalView.enableSetNeedsDisplay = false
        metalView.isPaused = true
        view = metalView
        super.init()
        metalView.delegate = self
    }

    func play() {
        guard resumedAt == nil else { return }
        resumedAt = CACurrentMediaTime()
        metalView.isPaused = false
    }

    func pause() {
        if let resumedAt {
            accumulatedTime += CACurrentMediaTime() - resumedAt
        }
        resumedAt = nil
        metalView.isPaused = true
    }

    func tearDown() {
        pause()
        metalView.delegate = nil
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let pass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let buffer = commandQueue.makeCommandBuffer(),
              let encoder = buffer.makeRenderCommandEncoder(descriptor: pass)
        else { return }

        var uniforms = ShaderUniforms(
            resolution: SIMD2(Float(view.drawableSize.width), Float(view.drawableSize.height)),
            mouse: mousePosition(in: view),
            time: Float(elapsedTime())
        )
        encoder.setRenderPipelineState(pipeline.state)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<ShaderUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        buffer.present(drawable)
        buffer.commit()
    }

    private func elapsedTime() -> CFTimeInterval {
        accumulatedTime + (resumedAt.map { CACurrentMediaTime() - $0 } ?? 0)
    }

    /// The window ignores mouse events, so the cursor is polled globally; no Accessibility permission needed.
    private func mousePosition(in view: MTKView) -> SIMD2<Float> {
        guard let window = view.window else { return .zero }
        let location = NSEvent.mouseLocation
        let scale = window.backingScaleFactor
        return SIMD2(Float((location.x - window.frame.minX) * scale), Float((location.y - window.frame.minY) * scale))
    }
}
