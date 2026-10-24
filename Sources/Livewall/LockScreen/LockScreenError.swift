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
            "Choose an Aerial wallpaper in System Settings → Wallpaper."
        case .aerialNotDownloaded(let name):
            "The Aerial “\(name)” is not downloaded yet. Wait for it to finish in System Settings."
        case .unsupportedKind(let kind):
            "\(kind.displayName) wallpapers cannot be used on the lock screen. Use a video or a shader."
        case .noVideoTrack:
            "The file has no video track."
        case .encodingFailed(let reason):
            "Could not render the video: \(reason)"
        case .noBackup:
            "There is no backup of the original Aerial."
        }
    }
}
