import Foundation

enum WorkshopError: LocalizedError {
    case missingAPIKey
    case missingUsername
    case invalidAPIKey
    case http(Int)
    case steamCMDMissing
    case notLoggedIn
    case downloadFailed(String)
    case unsupportedProject(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: String(localized: "Enter your Steam API key in Settings → Steam.")
        case .missingUsername: String(localized: "Enter your Steam username in Settings → Steam.")
        case .invalidAPIKey: String(localized: "Steam rejected the API key. Check it in Settings → Steam.")
        case .http(let status): String(localized: "Steam responded with HTTP error \(status).")
        case .steamCMDMissing: String(localized: "SteamCMD is not installed.")
        case .notLoggedIn: String(localized: "SteamCMD has no saved session. Use “Log in to SteamCMD” in Settings → Steam.")
        case .downloadFailed(let reason): String(localized: "Download failed: \(reason)")
        case .unsupportedProject(let type): String(localized: "Livewall cannot play “\(type)” wallpapers.")
        }
    }
}
