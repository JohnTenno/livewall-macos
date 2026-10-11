import Foundation

/// An Aerial wallpaper chosen in System Settings, and where macOS caches its video.
struct Aerial: Equatable {
    let id: String
    let name: String
    let videoURL: URL

    var isDownloaded: Bool { FileManager.default.fileExists(atPath: videoURL.path) }
}
