import Foundation

enum LibraryError: LocalizedError {
    case unsupportedFile(String)
    case missingIndex
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .unsupportedFile(let ext): "Formato no soportado: .\(ext). Usa .mp4, .mov, .html, .metal o una carpeta con index.html."
        case .missingIndex: "La carpeta no tiene un index.html."
        case .invalidURL: "La dirección no es válida. Debe empezar con http:// o https://."
        }
    }
}
