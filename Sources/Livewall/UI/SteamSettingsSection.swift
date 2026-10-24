import SwiftUI

struct SteamSettingsSection: View {
    @EnvironmentObject private var account: SteamAccount

    var body: some View {
        Section("Steam") {
            SecureField("API key", text: $account.apiKey)
            TextField("Steam username (login)", text: $account.username)
            HStack {
                Button("Log in to SteamCMD…") { account.openLoginTerminal() }
                    .disabled(!account.steamCMD.isInstalled)
                Link("Get API key", destination: URL(string: "https://steamcommunity.com/dev/apikey")!)
            }
            if let message = account.loginMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
            Text(account.steamCMD.isInstalled
                 ? "The API key is stored in the Keychain. Livewall never sees your password: SteamCMD keeps the session."
                 : "SteamCMD is not installed in Livewall's folder.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
