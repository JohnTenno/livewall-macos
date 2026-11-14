import SwiftUI

struct SteamSettingsSection: View {
    @EnvironmentObject private var account: SteamAccount

    var body: some View {
        Section("Steam") {
            SecureField("API key", text: $account.apiKey)
            TextField("Steam username (login)", text: $account.username)
            HStack {
                if account.isInstalled {
                    Button("Log in to SteamCMD…") { account.openLoginTerminal() }
                } else {
                    Button(account.isInstalling ? "Installing SteamCMD…" : "Install SteamCMD") {
                        Task { await account.installSteamCMD() }
                    }
                    .disabled(account.isInstalling)
                    if account.isInstalling {
                        ProgressView().controlSize(.small)
                    }
                }
                Link("Get API key", destination: URL(string: "https://steamcommunity.com/dev/apikey")!)
            }
            if let message = account.loginMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
            Text(account.isInstalled
                 ? "The API key is stored in the Keychain. Livewall never sees your password: SteamCMD keeps the session."
                 : "SteamCMD is required to download Workshop items. Click Install SteamCMD to set it up.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
