import Foundation

enum ShaderError: LocalizedError {
    case noMetalDevice
    case missingSource
    case compileFailed(String)

    var errorDescription: String? {
        switch self {
        case .noMetalDevice: "Este Mac no tiene un dispositivo Metal disponible."
        case .missingSource: "No se encontró el código del shader."
        case .compileFailed(let log): "El shader no compila:\n\(log)"
        }
    }
}
