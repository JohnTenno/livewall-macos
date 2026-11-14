import Foundation
import Security

/// Persists the Steam Web API key in the user's Application Support directory with user-only permissions (0600).
/// Migrates any legacy key found in the macOS Keychain on first read.
struct SteamAPIKeyStore {
    let fileURL: URL
    private let fileManager: FileManager
    private let legacyMigrator: (() -> String?)?

    init(
        fileURL: URL = WallpaperLibrary.defaultRootURL.appending(path: "steam-api-key"),
        fileManager: FileManager = .default,
        legacyMigrator: (() -> String?)? = Self.migrateLegacyKeychain
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.legacyMigrator = legacyMigrator
    }

    /// Reads the stored API key from disk, or migrates it from the legacy Keychain entry if missing.
    func read() -> String? {
        if fileManager.fileExists(atPath: fileURL.path) {
            guard let data = try? Data(contentsOf: fileURL),
                  let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                return nil
            }
            return text
        }
        guard let migrated = legacyMigrator?(), !migrated.isEmpty else { return nil }
        write(migrated)
        return migrated
    }

    /// Writes the key to disk with 0600 permissions, or removes the file if empty.
    func write(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try? fileManager.removeItem(at: fileURL)
            return
        }

        let directory = fileURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = Data(trimmed.utf8)
        try? data.write(to: fileURL, options: .atomic)
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    /// One-time migration: reads any key previously saved in the Keychain and deletes the Keychain entry.
    static func migrateLegacyKeychain() -> String? {
        let service = "com.tenno.livewall"
        let account = "steam-web-api-key"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let secret = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !secret.isEmpty else {
            return nil
        }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        return secret
    }
}
