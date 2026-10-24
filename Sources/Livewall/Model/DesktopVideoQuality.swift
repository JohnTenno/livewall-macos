import Foundation

/// Which file a video wallpaper plays on the desktop. The lock screen always uses the original.
enum DesktopVideoQuality: String, Codable, CaseIterable, Identifiable {
    case original
    case optimized
    case batterySaver

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .original: "Original file"
        case .optimized: "Optimized for this display"
        case .batterySaver: "Battery saver (30 fps)"
        }
    }

    var detail: String {
        switch self {
        case .original: "Plays the imported file as is. Larger-than-screen videos use more memory for no visible gain."
        case .optimized: "Resized to your display at the original frame rate. Looks the same and uses less memory."
        case .batterySaver: "Resized and capped at 30 fps. About half the CPU and GPU; motion is slightly less smooth."
        }
    }
}
