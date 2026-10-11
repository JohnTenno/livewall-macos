import Foundation

/// The user's Steam credentials: the Web API key lives in the Keychain, the username in UserDefaults.
@MainActor
final class SteamAccount: ObservableObject {
    private static let usernameKey = "steamUsername"
    private static let apiKeyAccount = "steam-web-api-key"

    private let keychain = KeychainStore(service: "com.tenno.livewall")
    private let defaults: UserDefaults

    @Published var apiKey: String {
        didSet { keychain.write(apiKey.trimmingCharacters(in: .whitespaces), account: Self.apiKeyAccount) }
    }
    @Published var username: String {
        didSet { defaults.set(username.trimmingCharacters(in: .whitespaces), forKey: Self.usernameKey) }
    }

    let steamCMD: SteamCMD

    init(defaults: UserDefaults = .standard, steamCMD: SteamCMD = SteamCMD()) {
        self.defaults = defaults
        self.steamCMD = steamCMD
        apiKey = keychain.read(account: Self.apiKeyAccount) ?? ""
        username = defaults.string(forKey: Self.usernameKey) ?? ""
    }

    @Published private(set) var loginMessage: String?

    var trimmedAPIKey: String { apiKey.trimmingCharacters(in: .whitespaces) }
    var trimmedUsername: String { username.trimmingCharacters(in: .whitespaces) }

    func openLoginTerminal() {
        do {
            guard !trimmedUsername.isEmpty else { throw WorkshopError.missingUsername }
            try steamCMD.openLoginTerminal(username: trimmedUsername)
            loginMessage = "Escribe tu contraseña y el código de Steam Guard en la Terminal. Se cierra sola al terminar."
        } catch {
            loginMessage = error.localizedDescription
        }
    }
}
