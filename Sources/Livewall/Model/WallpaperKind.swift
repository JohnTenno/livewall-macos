import Foundation

/// The rendering technology behind a wallpaper.
enum WallpaperKind: String, Codable, CaseIterable {
    case video
    case web
    case shader

    private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]
    private static let webExtensions: Set<String> = ["html", "htm"]
    private static let shaderExtensions: Set<String> = ["metal"]

    /// Infers the kind from a file extension, or nil when the file is not supported.
    init?(fileExtension: String) {
        let ext = fileExtension.lowercased()
        if Self.videoExtensions.contains(ext) {
            self = .video
        } else if Self.webExtensions.contains(ext) {
            self = .web
        } else if Self.shaderExtensions.contains(ext) {
            self = .shader
        } else {
            return nil
        }
    }

    var displayName: String {
        switch self {
        case .video: "Video"
        case .web: "Web"
        case .shader: "Shader"
        }
    }

    var systemImage: String {
        switch self {
        case .video: "film"
        case .web: "globe"
        case .shader: "wand.and.sparkles"
        }
    }
}
