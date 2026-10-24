import Foundation

enum ShaderError: LocalizedError {
    case noMetalDevice
    case missingSource
    case compileFailed(String)

    var errorDescription: String? {
        switch self {
        case .noMetalDevice: "This Mac has no Metal device available."
        case .missingSource: "Shader source not found."
        case .compileFailed(let log): "The shader does not compile:\n\(log)"
        }
    }
}
