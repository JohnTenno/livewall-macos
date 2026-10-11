import SwiftUI

struct SteamSettingsSection: View {
    @EnvironmentObject private var account: SteamAccount

    var body: some View {
        Section("Steam") {
            SecureField("API key", text: $account.apiKey)
            TextField("Usuario de Steam (inicio de sesión)", text: $account.username)
            HStack {
                Button("Iniciar sesión en SteamCMD…") { account.openLoginTerminal() }
                    .disabled(!account.steamCMD.isInstalled)
                Link("Obtener API key", destination: URL(string: "https://steamcommunity.com/dev/apikey")!)
            }
            if let message = account.loginMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
            Text(account.steamCMD.isInstalled
                 ? "La API key se guarda en el Llavero. Livewall nunca ve tu contraseña: SteamCMD guarda la sesión."
                 : "SteamCMD no está instalado en la carpeta de Livewall.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
