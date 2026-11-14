import Foundation

/// The user's Steam setup: the Web API key (Keychain) for searching, and a QR sign-in for downloading.
@MainActor
final class SteamAccount: ObservableObject {
    private static let accountNameKey = "steamAccountName"
    private static let apiKeyAccount = "steam-web-api-key"
    private static let legacyKeys = ["steamUsername"]

    private let keychain = KeychainStore(service: "com.tenno.livewall")
    private let defaults: UserDefaults

    @Published var apiKey: String {
        didSet { keychain.write(apiKey.trimmingCharacters(in: .whitespaces), account: Self.apiKeyAccount) }
    }
    /// Set once the Steam app approved a QR code; DepotDownloader logs in with it and its saved token.
    @Published private(set) var accountName: String? {
        didSet { defaults.set(accountName, forKey: Self.accountNameKey) }
    }

    let downloader: DepotDownloader
    @Published private(set) var isInstalled: Bool
    @Published private(set) var isInstalling = false
    @Published private(set) var isSigningIn = false
    /// The code to show while signing in; it changes when Steam refreshes the challenge.
    @Published private(set) var qrCode: SteamQRCode?
    @Published private(set) var message: String?
    private var signInTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard, downloader: DepotDownloader = DepotDownloader()) {
        self.defaults = defaults
        self.downloader = downloader
        apiKey = keychain.read(account: Self.apiKeyAccount) ?? ""
        accountName = defaults.string(forKey: Self.accountNameKey)
        isInstalled = downloader.isInstalled
        Self.legacyKeys.forEach(defaults.removeObject(forKey:))
    }

    var trimmedAPIKey: String { apiKey.trimmingCharacters(in: .whitespaces) }

    func installDownloader() async {
        isInstalling = true
        message = nil
        defer {
            isInstalling = false
            isInstalled = downloader.isInstalled
        }
        do {
            try await downloader.install()
            // SteamCMD from older versions is no longer used.
            try? FileManager.default.removeItem(at: WallpaperLibrary.defaultRootURL.appending(path: "steamcmd"))
        } catch {
            message = error.localizedDescription
        }
    }

    func signIn() {
        guard !isSigningIn else { return }
        isSigningIn = true
        message = nil
        qrCode = nil
        signInTask = Task {
            defer {
                isSigningIn = false
                qrCode = nil
            }
            do {
                let name = try await downloader.signIn { [weak self] code in
                    Task { @MainActor in if self?.qrCode != code { self?.qrCode = code } }
                }
                accountName = name
            } catch is CancellationError {
            } catch {
                if !Task.isCancelled { message = error.localizedDescription }
            }
        }
    }

    func cancelSignIn() {
        signInTask?.cancel()
    }

    func signOut() {
        downloader.signOut()
        accountName = nil
    }

    /// Called when a download finds the saved session gone (expired or revoked in Steam).
    func sessionExpired() {
        accountName = nil
    }
}
