import Foundation

enum LibraryError: LocalizedError {
    case unsupportedFile(String)
    case missingIndex
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .unsupportedFile(let ext): "Unsupported format: .\(ext). Use .mp4, .mov, .html, .metal or a folder with index.html."
        case .missingIndex: "The folder has no index.html."
        case .invalidURL: "Invalid address. It must start with http:// or https://."
        }
    }
}
