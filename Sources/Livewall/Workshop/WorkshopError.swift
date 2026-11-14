import Foundation

enum WorkshopError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case http(Int)
    case downloaderMissing
    case notLoggedIn
    case downloadFailed(String)
    case unsupportedProject(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: String(localized: "Enter your Steam API key in Settings → Steam.")
        case .invalidAPIKey: String(localized: "Steam rejected the API key. Check it in Settings → Steam.")
        case .http(let status): String(localized: "Steam responded with HTTP error \(status).")
        case .downloaderMissing: String(localized: "The Steam downloader is not installed. Install it in Settings → Steam.")
        case .notLoggedIn: String(localized: "Sign in with Steam to download. Scan the QR code in Settings → Steam.")
        case .downloadFailed(let reason): String(localized: "Download failed: \(reason)")
        case .unsupportedProject(let type): String(localized: "Livewall cannot play “\(type)” wallpapers.")
        }
    }
}
