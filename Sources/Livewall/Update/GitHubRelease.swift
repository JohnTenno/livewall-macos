import Foundation

/// The parts of a GitHub "latest release" response the updater needs.
struct GitHubRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        private enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let assets: [Asset]

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }

    var version: AppVersion? { AppVersion(tagName) }

    /// The app zip attached to the release, only if it is served by GitHub over HTTPS.
    var appArchiveURL: URL? {
        assets.first { $0.name == "Livewall.zip" }.map(\.browserDownloadURL).flatMap { url in
            url.scheme == "https" && (url.host == "github.com" || url.host?.hasSuffix(".github.com") == true) ? url : nil
        }
    }
}
