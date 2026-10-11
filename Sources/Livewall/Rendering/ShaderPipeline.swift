import Metal

/// Compiles a wallpaper shader into a render pipeline. Separate from the renderer so it can be validated headlessly.
struct ShaderPipeline {
    static let pixelFormat = MTLPixelFormat.bgra8Unorm

    let device: MTLDevice
    let state: MTLRenderPipelineState

    init(userSource: String, device: MTLDevice? = MTLCreateSystemDefaultDevice()) throws {
        guard let device else { throw ShaderError.noMetalDevice }
        do {
            let library = try device.makeLibrary(source: ShaderSourceBuilder.build(userSource: userSource), options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: ShaderSourceBuilder.vertexFunction)
            descriptor.fragmentFunction = library.makeFunction(name: ShaderSourceBuilder.fragmentFunction)
            descriptor.colorAttachments[0].pixelFormat = Self.pixelFormat
            state = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            throw ShaderError.compileFailed(error.localizedDescription)
        }
        self.device = device
    }
}
