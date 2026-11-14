import Foundation

enum UpdateError: LocalizedError {
    case badResponse(Int)
    case noArchive
    case unzipFailed
    case wrongBundle

    var errorDescription: String? {
        switch self {
        case .badResponse(let status): String(localized: "GitHub answered with status \(status).")
        case .noArchive: String(localized: "The latest release has no Livewall.zip attached.")
        case .unzipFailed: String(localized: "Could not unpack the downloaded update.")
        case .wrongBundle: String(localized: "The downloaded file is not Livewall.")
        }
    }
}
