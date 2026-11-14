import Foundation
import Testing
@testable import Livewall

@Suite struct SteamAPIKeyStoreTests {
    @Test func savesAndReadsAPIKey() throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: "key-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appending(path: "steam-api-key")
        let store = SteamAPIKeyStore(fileURL: fileURL, legacyMigrator: nil)

        #expect(store.read() == nil)

        store.write("1234567890ABCDEF1234567890ABCDEF")
        #expect(store.read() == "1234567890ABCDEF1234567890ABCDEF")

        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue
        #expect(permissions == 0o600)
    }

    @Test func clearsKeyWhenEmpty() throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: "key-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appending(path: "steam-api-key")
        let store = SteamAPIKeyStore(fileURL: fileURL, legacyMigrator: nil)

        store.write("SAMPLE_KEY")
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
        #expect(store.read() == "SAMPLE_KEY")

        store.write("   ")
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        #expect(store.read() == nil)
    }

    @Test func trimsWhitespaceOnReadAndWrite() throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: "key-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appending(path: "steam-api-key")
        let store = SteamAPIKeyStore(fileURL: fileURL, legacyMigrator: nil)

        store.write("  MY_SECRET_KEY \n ")
        #expect(store.read() == "MY_SECRET_KEY")
    }

    @Test func migratesLegacyKeyWhenFileIsMissing() throws {
        let tempDir = FileManager.default.temporaryDirectory.appending(path: "key-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fileURL = tempDir.appending(path: "steam-api-key")
        var migrationCalls = 0
        let store = SteamAPIKeyStore(fileURL: fileURL, legacyMigrator: {
            migrationCalls += 1
            return "MIGRATED_SECRET_KEY"
        })

        #expect(migrationCalls == 0)
        #expect(store.read() == "MIGRATED_SECRET_KEY")
        #expect(migrationCalls == 1)

        // The file should now exist with 0600 permissions.
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue
        #expect(permissions == 0o600)

        // A second read returns from the file without calling legacyMigrator again.
        #expect(store.read() == "MIGRATED_SECRET_KEY")
        #expect(migrationCalls == 1)
    }
}
