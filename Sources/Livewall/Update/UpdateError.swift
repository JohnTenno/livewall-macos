import Foundation

enum UpdateError: LocalizedError {
    case badResponse(Int)
    case noArchive
    case unzipFailed
    case wrongBundle

    var errorDescription: String? {
        switch self {
        case .badResponse(let status): "GitHub answered with status \(status)."
        case .noArchive: "The latest release has no Livewall.zip attached."
        case .unzipFailed: "Could not unpack the downloaded update."
        case .wrongBundle: "The downloaded file is not Livewall."
        }
    }
}
