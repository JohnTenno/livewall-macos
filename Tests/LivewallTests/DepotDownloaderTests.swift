import Foundation
import Testing
@testable import Livewall

@Suite struct DepotDownloaderTests {
    /// Two text rows of a 2×2 code: "██" dark, "  " light, as DepotDownloader prints them.
    private let output = """
    Connecting to Steam3... Done!
    Logging in with QR code...
    \(SteamQRCode.header)

    ██  
      ██

    """

    @Test func readsTheQRCodeFromTheOutput() throws {
        let code = try #require(SteamQRCode.latest(in: output))
        #expect(code.modules == [[true, false], [false, true]])
    }

    @Test func waitsForTheWholeCodeAndPicksTheNewest() throws {
        #expect(SteamQRCode.latest(in: "\(SteamQRCode.header)\n██  \n") == nil)
        let refreshed = output + "The QR code has changed:\n\(SteamQRCode.header)\n  ██\n██  \n"
        #expect(try #require(SteamQRCode.latest(in: refreshed)).modules == [[false, true], [true, false]])
    }

    @Test func readsTheAccountNameAfterApproval() throws {
        let done = "Success! Next time you can login with -username tenno_player -remember-password instead of -qr."
        #expect(try DepotDownloader.accountName(in: done) == "tenno_player")
        #expect(throws: WorkshopError.self) { try DepotDownloader.accountName(in: "Failed to authenticate with Steam") }
    }

    @Test func reportsAMissingSessionAsNotLoggedIn() {
        let output = "Enter account password for \"me\": \nUnhandled exception. System.ArgumentException: LogOn requires a username"
        #expect {
            try DepotDownloader.downloadedFolder(URL(fileURLWithPath: "/nonexistent"), output: output)
        } throws: { error in
            if case WorkshopError.notLoggedIn = error { true } else { false }
        }
    }

    @Test func acceptsACompletedDownload() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "dd-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "{}".write(to: folder.appending(path: "project.json"), atomically: true, encoding: .utf8)
        let output = "Depot 431960 - Downloaded 38125248 bytes\nTotal downloaded: 38125248 bytes"
        #expect(try DepotDownloader.downloadedFolder(folder, output: output) == folder)
    }

    @Test func installsFromTheReleaseZip() async throws {
        let tmp = FileManager.default.temporaryDirectory.appending(path: "dd-install-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let source = tmp.appending(path: "src")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try "#!/bin/sh\n".write(to: source.appending(path: "DepotDownloader"), atomically: true, encoding: .utf8)
        let zip = tmp.appending(path: "DepotDownloader.zip")
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-c", "-k", source.path, zip.path]
        try ditto.run()
        ditto.waitUntilExit()

        let downloader = DepotDownloader(root: tmp.appending(path: "root"))
        #expect(!downloader.isInstalled)
        try await downloader.install(from: zip)
        #expect(downloader.isInstalled)
    }
}
