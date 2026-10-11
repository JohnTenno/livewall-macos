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
        case .missingAPIKey: "Pon tu API key de Steam en Ajustes → Steam."
        case .missingUsername: "Pon tu usuario de Steam en Ajustes → Steam."
        case .invalidAPIKey: "Steam rechazó la API key. Revísala en Ajustes → Steam."
        case .http(let status): "Steam respondió con el error HTTP \(status)."
        case .steamCMDMissing: "SteamCMD no está instalado."
        case .notLoggedIn: "SteamCMD no tiene tu sesión guardada. Usa «Iniciar sesión en SteamCMD» en Ajustes → Steam."
        case .downloadFailed(let reason): "La descarga falló: \(reason)"
        case .unsupportedProject(let type): "Livewall no puede reproducir fondos de tipo «\(type)»."
        }
    }
}
