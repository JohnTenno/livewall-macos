import Foundation
import Testing
@testable import Livewall

@Suite struct AppUpdaterTests {
    @Test func comparesVersionsNumerically() throws {
        #expect(try #require(AppVersion("0.1.0")) < #require(AppVersion("v0.2.0")))
        #expect(try #require(AppVersion("0.9")) < #require(AppVersion("0.10.0")))
        #expect(try #require(AppVersion("1.0")) == #require(AppVersion("1.0.0")))
        #expect(AppVersion("1.0-beta") == nil)
    }

    @Test func onlyAcceptsTheZipServedByGitHub() throws {
        func release(_ url: String) throws -> GitHubRelease {
            let json = #"{"tag_name":"v0.2.0","assets":[{"name":"Livewall.zip","browser_download_url":"\#(url)"}]}"#
            return try JSONDecoder().decode(GitHubRelease.self, from: Data(json.utf8))
        }
        #expect(try release("https://github.com/JohnTenno/livewall-macos/releases/download/v0.2.0/Livewall.zip").appArchiveURL != nil)
        #expect(try release("http://github.com/x/Livewall.zip").appArchiveURL == nil)
        #expect(try release("https://evilgithub.com.example/Livewall.zip").appArchiveURL == nil)
        #expect(try release("https://evilgithub.com/Livewall.zip").appArchiveURL == nil)
    }
}
