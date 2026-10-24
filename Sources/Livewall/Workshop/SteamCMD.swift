import Foundation

/// Drives Valve's SteamCMD to download Workshop items with the user's own (cached) Steam session.
/// Livewall never sees the password: the first login happens in a visible Terminal window.
final class SteamCMD {
    static var defaultRoot: URL {
        WallpaperLibrary.defaultRootURL.appending(path: "steamcmd", directoryHint: .isDirectory)
    }

    private let root: URL
    private var script: URL { root.appending(path: "steamcmd.sh") }

    init(root: URL = SteamCMD.defaultRoot) {
        self.root = root
    }

    var isInstalled: Bool { FileManager.default.isExecutableFile(atPath: script.path) }

    /// Opens Terminal so the user can type their password and Steam Guard code once.
    func openLoginTerminal(username: String) throws {
        guard isInstalled else { throw WorkshopError.steamCMDMissing }
        let command = "\(shellQuoted(script.path)) +login \(shellQuoted(username)) +quit; exit"
        let source = """
        tell application "Terminal"
            activate
            do script "\(command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))"
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            throw WorkshopError.downloadFailed(error[NSAppleScript.errorMessage] as? String ?? "could not open Terminal")
        }
    }

    /// Downloads an item and returns its content folder. Fails fast instead of prompting when no session is cached.
    func download(itemID: String, appID: Int, username: String) async throws -> URL {
        guard isInstalled else { throw WorkshopError.steamCMDMissing }
        guard !username.isEmpty else { throw WorkshopError.missingUsername }

        let output = try await run([
            "+@NoPromptForPassword", "1",
            "+@sSteamCmdForcePlatformType", "windows",
            "+login", username,
            "+workshop_download_item", String(appID), itemID,
            "+quit",
        ])
        return try Self.parseDownloadOutput(output, itemID: itemID)
    }

    /// Extracts the content folder from SteamCMD's console output.
    static func parseDownloadOutput(_ output: String, itemID: String) throws -> URL {
        if let range = output.range(of: #"Downloaded item \#(itemID) to "([^"]+)""#, options: .regularExpression) {
            let match = String(output[range])
            if let start = match.firstIndex(of: "\""), let end = match.lastIndex(of: "\""), start < end {
                return URL(fileURLWithPath: String(match[match.index(after: start)..<end]), isDirectory: true)
            }
        }
        let lowered = output.lowercased()
        if lowered.contains("password") || lowered.contains("cached credentials") || lowered.contains("login failure") {
            throw WorkshopError.notLoggedIn
        }
        let errorLine = output.split(separator: "\n").last { $0.contains("ERROR") || $0.contains("FAILED") }
        throw WorkshopError.downloadFailed(errorLine.map(String.init) ?? "SteamCMD did not report the downloaded folder")
    }

    private func run(_ arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = script
        process.arguments = arguments
        process.currentDirectoryURL = root
        process.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        // Drain the pipe while the process runs; waiting for exit first deadlocks once the pipe buffer fills.
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: String(decoding: data, as: UTF8.self))
            }
        }
    }

    private func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
