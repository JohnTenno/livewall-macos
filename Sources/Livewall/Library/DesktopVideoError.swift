import Foundation

enum DesktopVideoError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self { case .failed(let message): "Could not optimize the video: \(message)" }
    }
}
