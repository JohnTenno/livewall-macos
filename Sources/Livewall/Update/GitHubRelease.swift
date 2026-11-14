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
        guard let asset = assets.first(where: { $0.name == "Livewall.zip" }) else { return nil }
        let url = asset.browserDownloadURL
        guard url.scheme == "https" else { return nil }
        let host = url.host ?? ""
        guard host == "github.com" || host.hasSuffix(".github.com") else { return nil }
        return url
    }
}
