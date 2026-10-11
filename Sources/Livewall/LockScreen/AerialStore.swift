import Foundation

/// Finds the Aerial selected in System Settings and swaps its cached video for a Livewall movie.
///
/// Since macOS 26 Aerials are cached per user in
/// `~/Library/Application Support/com.apple.wallpaper/aerials/videos/<assetID>.mov`, so no admin rights are needed.
/// The original is kept in Livewall's folder and its extended attributes (`LastETag`, `SourceURL`) are copied to
/// the replacement so the system treats the cache as up to date instead of downloading it again.
final class AerialStore {
    private static let aerialsProvider = "com.apple.wallpaper.choice.aerials"
    private static let restartedProcesses = ["WallpaperAerialsExtension", "WallpaperAgent"]

    private let wallpaperRoot: URL
    private let backupRoot: URL
    private let fileManager = FileManager.default
    private let restartServices: () -> Void

    static var defaultWallpaperRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/com.apple.wallpaper")
    }

    init(wallpaperRoot: URL = AerialStore.defaultWallpaperRoot,
         backupRoot: URL = WallpaperLibrary.defaultRootURL.appending(path: "AerialBackups", directoryHint: .isDirectory),
         restartServices: @escaping () -> Void = AerialStore.restartWallpaperServices) {
        self.wallpaperRoot = wallpaperRoot
        self.backupRoot = backupRoot
        self.restartServices = restartServices
    }

    func selectedAerial() -> Aerial? {
        guard let id = selectedAssetID() else { return nil }
        return Aerial(
            id: id,
            name: displayName(forAssetID: id) ?? id,
            videoURL: wallpaperRoot.appending(path: "aerials/videos/\(id).mov")
        )
    }

    func hasBackup(for aerial: Aerial) -> Bool {
        fileManager.fileExists(atPath: backupURL(for: aerial).path)
    }

    /// Apple's movie for this Aerial: the backup once Livewall has replaced it, otherwise the cached file.
    func originalVideoURL(for aerial: Aerial) -> URL {
        hasBackup(for: aerial) ? backupURL(for: aerial) : aerial.videoURL
    }

    func install(_ movie: URL, for aerial: Aerial) throws {
        guard aerial.isDownloaded else { throw LockScreenError.aerialNotDownloaded(aerial.name) }
        try fileManager.createDirectory(at: backupRoot, withIntermediateDirectories: true)

        let backup = backupURL(for: aerial)
        if !fileManager.fileExists(atPath: backup.path) {
            try fileManager.copyItem(at: aerial.videoURL, to: backup)
        }

        let staging = aerial.videoURL.deletingLastPathComponent().appending(path: ".livewall-\(UUID().uuidString).mov")
        try fileManager.copyItem(at: movie, to: staging)
        copyfile(backup.path, staging.path, nil, copyfile_flags_t(COPYFILE_XATTR))
        _ = try fileManager.replaceItemAt(aerial.videoURL, withItemAt: staging)
        restartServices()
    }

    func restore(_ aerial: Aerial) throws {
        let backup = backupURL(for: aerial)
        guard fileManager.fileExists(atPath: backup.path) else { throw LockScreenError.noBackup }
        _ = try fileManager.replaceItemAt(aerial.videoURL, withItemAt: backup)
        restartServices()
    }

    private func backupURL(for aerial: Aerial) -> URL {
        backupRoot.appending(path: "\(aerial.id).mov")
    }

    /// The agents are relaunched by launchd and reload the cached video.
    static func restartWallpaperServices() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = Self.restartedProcesses
        try? process.run()
        process.waitUntilExit()
    }

    // MARK: - System Settings store

    /// Reads `Store/Index.plist`; each wallpaper choice holds a nested binary plist with the Aerial's `assetID`.
    private func selectedAssetID() -> String? {
        let indexURL = wallpaperRoot.appending(path: "Store/Index.plist")
        guard let data = try? Data(contentsOf: indexURL),
              let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }

        // The "all spaces and displays" choice is what the lock screen uses; fall back to any other choice.
        if let shared = root["AllSpacesAndDisplays"], let id = findAssetID(in: shared) {
            return id
        }
        return findAssetID(in: root)
    }

    private func findAssetID(in node: Any) -> String? {
        if let dictionary = node as? [String: Any] {
            if dictionary["Provider"] as? String == Self.aerialsProvider,
               let configuration = dictionary["Configuration"] as? Data,
               let decoded = try? PropertyListSerialization.propertyList(from: configuration, format: nil) as? [String: Any],
               let id = decoded["assetID"] as? String {
                return id
            }
            for key in dictionary.keys.sorted() {
                if let id = findAssetID(in: dictionary[key]!) { return id }
            }
        } else if let array = node as? [Any] {
            for element in array {
                if let id = findAssetID(in: element) { return id }
            }
        }
        return nil
    }

    private func displayName(forAssetID id: String) -> String? {
        let manifestURL = wallpaperRoot.appending(path: "aerials/manifest/entries.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let assets = json["assets"] as? [[String: Any]],
              let asset = assets.first(where: { $0["id"] as? String == id })
        else { return nil }
        return asset["accessibilityLabel"] as? String
    }
}
