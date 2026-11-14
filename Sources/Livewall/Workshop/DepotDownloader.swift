import Foundation

/// Drives SteamRE's DepotDownloader to sign in with a Steam QR code and download Workshop items.
/// Livewall never sees a password: the Steam app approves the QR and DepotDownloader saves the session token.
final class DepotDownloader {
    static let version = "3.4.0"

    static var defaultRoot: URL {
        WallpaperLibrary.defaultRootURL.appending(path: "depotdownloader", directoryHint: .isDirectory)
    }

    static var releaseURL: URL {
        #if arch(arm64)
        let platform = "macos-arm64"
        #else
        let platform = "macos-x64"
        #endif
        return URL(string: "https://github.com/SteamRE/DepotDownloader/releases/download/DepotDownloader_\(version)/DepotDownloader-\(platform).zip")!
    }

    private let root: URL
    private var binary: URL { root.appending(path: "DepotDownloader") }
    /// Remembers which token file the sign-in created, so signing out can delete it.
    private var sessionRecord: URL { root.appending(path: "session-path") }
    private var downloads: URL { root.appending(path: "downloads", directoryHint: .isDirectory) }

    init(root: URL = DepotDownloader.defaultRoot) {
        self.root = root
    }

    var isInstalled: Bool { FileManager.default.isExecutableFile(atPath: binary.path) }

    func install(from url: URL = DepotDownloader.releaseURL) async throws {
        let archive: URL
        if url.isFileURL {
            archive = url
        } else {
            let (downloaded, response) = try await URLSession.shared.download(from: url)
            if let status = (response as? HTTPURLResponse)?.statusCode, status != 200 {
                throw WorkshopError.downloadFailed("HTTP \(status)")
            }
            archive = downloaded
        }
        defer { if !url.isFileURL { try? FileManager.default.removeItem(at: archive) } }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", archive.path, root.path]
        try ditto.run()
        ditto.waitUntilExit()
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
        guard ditto.terminationStatus == 0, isInstalled else {
            throw WorkshopError.downloadFailed("Could not unpack DepotDownloader")
        }
    }

    /// Shows QR codes through `onQRCode` until the Steam app approves one; returns the account name.
    /// Reading Wallpaper Engine's own manifest is the cheapest request that needs a signed-in owner.
    func signIn(onQRCode: @escaping @Sendable (SteamQRCode) -> Void) async throws -> String {
        guard isInstalled else { throw WorkshopError.downloaderMissing }
        let scratch = downloads.appending(path: "sign-in-\(UUID().uuidString)")
        let started = Date()
        defer { try? FileManager.default.removeItem(at: scratch) }
        let output = try await run([
            "-app", String(WorkshopQuery.wallpaperEngineAppID), "-manifest-only",
            "-qr", "-remember-password", "-dir", scratch.path,
        ]) { output in
            if let code = SteamQRCode.latest(in: output) { onQRCode(code) }
        }
        let name = try Self.accountName(in: output)
        if let token = Self.newestSessionFile(since: started) {
            try? token.path.write(to: sessionRecord, atomically: true, encoding: .utf8)
        }
        return name
    }

    /// Downloads an item with the saved session into a temporary folder the caller imports from and then deletes.
    func download(itemID: String, account: String) async throws -> URL {
        guard isInstalled else { throw WorkshopError.downloaderMissing }
        guard !account.isEmpty else { throw WorkshopError.notLoggedIn }
        let folder = downloads.appending(path: itemID)
        try? FileManager.default.removeItem(at: folder)
        let output = try await run([
            "-app", String(WorkshopQuery.wallpaperEngineAppID), "-pubfile", itemID,
            "-username", account, "-remember-password", "-dir", folder.path,
        ])
        return try Self.downloadedFolder(folder, output: output)
    }

    func signOut() {
        if let path = try? String(contentsOf: sessionRecord, encoding: .utf8) {
            try? FileManager.default.removeItem(atPath: path)
        }
        try? FileManager.default.removeItem(at: sessionRecord)
    }

    /// .NET keeps DepotDownloader's account.config in its isolated storage under Application Support (it ignores $HOME),
    /// in a folder named after a hash of the binary's path. The file written during sign-in is ours.
    private static func newestSessionFile(since date: Date) -> URL? {
        let storage = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/IsolatedStorage")
        let files = FileManager.default.enumerator(at: storage, includingPropertiesForKeys: [.contentModificationDateKey])
        return (files?.allObjects as? [URL] ?? [])
            .filter { $0.lastPathComponent == "account.config" }
            .compactMap { url in (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate).map { (url, $0) } }
            .filter { $0.1 >= date.addingTimeInterval(-1) }
            .max { $0.1 < $1.1 }?.0
    }

    static func accountName(in output: String) throws -> String {
        if let match = output.firstMatch(of: #/Next time you can login with -username (\S+)/#) {
            return String(match.output.1)
        }
        throw WorkshopError.downloadFailed(lastMeaningfulLine(of: output) ?? "Steam did not confirm the sign-in")
    }

    static func downloadedFolder(_ folder: URL, output: String) throws -> URL {
        // Without a saved session DepotDownloader asks for a password (stdin is empty) and stops.
        if output.contains("Enter account password") || output.contains("LogOn requires") {
            throw WorkshopError.notLoggedIn
        }
        guard output.contains("Total downloaded"),
              FileManager.default.fileExists(atPath: folder.appending(path: "project.json").path) else {
            throw WorkshopError.downloadFailed(lastMeaningfulLine(of: output) ?? "DepotDownloader did not download the item")
        }
        return folder
    }

    private static func lastMeaningfulLine(of output: String) -> String? {
        output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .last { !$0.isEmpty && !$0.hasPrefix("at ") && !$0.contains("█") }
    }

    /// Runs DepotDownloader, reporting the output so far as it grows, and returns all of it.
    private func run(_ arguments: [String], onOutput: (@Sendable (String) -> Void)? = nil) async throws -> String {
        let process = Process()
        process.executableURL = binary
        process.arguments = arguments
        process.currentDirectoryURL = root
        process.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        let buffer = OutputBuffer()

        return try await withTaskCancellationHandler {
            try process.run()
            return await withCheckedContinuation { continuation in
                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let chunk = handle.availableData
                    guard !chunk.isEmpty else {
                        handle.readabilityHandler = nil
                        process.waitUntilExit()
                        continuation.resume(returning: buffer.text)
                        return
                    }
                    // Append first: `onOutput?(buffer.append(chunk))` would skip the append when onOutput is nil.
                    let text = buffer.append(chunk)
                    onOutput?(text)
                }
            }
        } onCancel: {
            process.terminate()
        }
    }
}

