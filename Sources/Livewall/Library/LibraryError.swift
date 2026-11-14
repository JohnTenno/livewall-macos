import Foundation

enum LibraryError: LocalizedError {
    case unsupportedFile(String)
    case missingIndex
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .unsupportedFile(let ext): String(localized: "Unsupported format: .\(ext). Use .mp4, .mov, .html, .metal or a folder with index.html.")
        case .missingIndex: String(localized: "The folder has no index.html.")
        case .invalidURL: String(localized: "Invalid address. It must start with http:// or https://.")
        }
    }
}
