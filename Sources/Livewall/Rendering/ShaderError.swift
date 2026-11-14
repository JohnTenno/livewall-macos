import Foundation

enum ShaderError: LocalizedError {
    case noMetalDevice
    case missingSource
    case compileFailed(String)

    var errorDescription: String? {
        switch self {
        case .noMetalDevice: String(localized: "This Mac has no Metal device available.")
        case .missingSource: String(localized: "Shader source not found.")
        case .compileFailed(let log): String(localized: "The shader does not compile:\n\(log)")
        }
    }
}
