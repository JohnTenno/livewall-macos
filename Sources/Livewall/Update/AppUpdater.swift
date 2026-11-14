import AppKit

/// Checks this repo's latest GitHub release and, when the user agrees, swaps the running app for it and relaunches.
@MainActor
final class AppUpdater: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(String)
        case installing
        case failed(String)
    }

    // Fixed on purpose: the app only ever trusts releases from its own repository.
    static let latestReleaseURL = URL(string: "https://api.github.com/repos/JohnTenno/livewall-macos/releases/latest")!

    @Published private(set) var state = State.idle
    private var release: GitHubRelease?

    func check() async {
        guard state != .checking, state != .installing else { return }
        state = .checking
        do {
            var request = URLRequest(url: Self.latestReleaseURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            try Self.requireSuccess(response)
            let latest = try JSONDecoder().decode(GitHubRelease.self, from: data)
            if let version = latest.version, let current = AppVersion.current, current < version, latest.appArchiveURL != nil {
                release = latest
                state = .available(version.description)
            } else {
                state = .upToDate
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func install() async {
        guard let url = release?.appArchiveURL else { return }
        state = .installing
        do {
            let (zip, response) = try await URLSession.shared.download(from: url)
            try Self.requireSuccess(response)
            let newApp = try Self.unpack(zip)
            let current = Bundle.main.bundleURL
            _ = try FileManager.default.replaceItemAt(current, withItemAt: newApp)
            Self.relaunch(current)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private static func requireSuccess(_ response: URLResponse) throws {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw UpdateError.badResponse(status) }
    }

    /// Unzips into a fresh temp folder and checks the result is really Livewall before it replaces anything.
    private static func unpack(_ zip: URL) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("livewall-update-\(UUID().uuidString)")
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", zip.path, folder.path]
        try ditto.run()
        ditto.waitUntilExit()
        guard ditto.terminationStatus == 0 else { throw UpdateError.unzipFailed }
        let app = folder.appendingPathComponent("Livewall.app")
        guard Bundle(url: app)?.bundleIdentifier == Bundle.main.bundleIdentifier else { throw UpdateError.wrongBundle }
        return app
    }

    /// Starts the new copy once this process has exited, then quits.
    private static func relaunch(_ app: URL) {
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/sh")
        shell.arguments = ["-c", "while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$0\"", app.path]
        try? shell.run()
        NSApp.terminate(nil)
    }
}
