import Metal

/// Compiles a wallpaper shader into a render pipeline. Separate from the renderer so it can be validated headlessly.
struct ShaderPipeline {
    static let pixelFormat = MTLPixelFormat.bgra8Unorm

    let device: MTLDevice
    let state: MTLRenderPipelineState

    /// - Parameter blending: when true, output is mixed over the existing contents using the encoder's blend color alpha.
    init(userSource: String, blending: Bool = false, device: MTLDevice? = MTLCreateSystemDefaultDevice()) throws {
        guard let device else { throw ShaderError.noMetalDevice }
        do {
            let library = try device.makeLibrary(source: ShaderSourceBuilder.build(userSource: userSource), options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: ShaderSourceBuilder.vertexFunction)
            descriptor.fragmentFunction = library.makeFunction(name: ShaderSourceBuilder.fragmentFunction)
            let attachment = descriptor.colorAttachments[0]!
            attachment.pixelFormat = Self.pixelFormat
            if blending {
                attachment.isBlendingEnabled = true
                attachment.sourceRGBBlendFactor = .blendAlpha
                attachment.destinationRGBBlendFactor = .oneMinusBlendAlpha
                attachment.sourceAlphaBlendFactor = .one
                attachment.destinationAlphaBlendFactor = .zero
            }
            state = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            throw ShaderError.compileFailed(error.localizedDescription)
        }
        self.device = device
    }
}
