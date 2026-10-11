import Foundation

enum LockScreenError: LocalizedError {
    case noAerialSelected
    case aerialNotDownloaded(String)
    case unsupportedKind(WallpaperKind)
    case noVideoTrack
    case encodingFailed(String)
    case noBackup

    var errorDescription: String? {
        switch self {
        case .noAerialSelected:
            "Elige un fondo Aerial en Ajustes del Sistema → Fondo de pantalla."
        case .aerialNotDownloaded(let name):
            "El Aerial «\(name)» aún no se descarga. Espera a que termine en Ajustes del Sistema."
        case .unsupportedKind(let kind):
            "Los fondos de tipo \(kind.displayName) no se pueden usar en la pantalla de bloqueo. Usa un video o un shader."
        case .noVideoTrack:
            "El archivo no tiene pista de video."
        case .encodingFailed(let reason):
            "No se pudo generar el video: \(reason)"
        case .noBackup:
            "No hay respaldo del Aerial original."
        }
    }
}
