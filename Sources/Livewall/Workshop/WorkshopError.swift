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
        case .missingAPIKey: "Enter your Steam API key in Settings → Steam."
        case .missingUsername: "Enter your Steam username in Settings → Steam."
        case .invalidAPIKey: "Steam rejected the API key. Check it in Settings → Steam."
        case .http(let status): "Steam responded with HTTP error \(status)."
        case .steamCMDMissing: "SteamCMD is not installed."
        case .notLoggedIn: "SteamCMD has no saved session. Use “Log in to SteamCMD” in Settings → Steam."
        case .downloadFailed(let reason): "Download failed: \(reason)"
        case .unsupportedProject(let type): "Livewall cannot play “\(type)” wallpapers."
        }
    }
}
