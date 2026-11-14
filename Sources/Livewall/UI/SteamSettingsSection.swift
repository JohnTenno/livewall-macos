import SwiftUI

/// Steam setup as two separate, numbered steps: an API key to search, and a QR sign-in to download.
struct SteamSettingsSection: View {
    @EnvironmentObject private var account: SteamAccount

    var body: some View {
        Section {
            HStack {
                SecureField("API key", text: $account.apiKey)
                Link("Get a free key", destination: URL(string: "https://steamcommunity.com/dev/apikey")!)
            }
            status(done: !account.trimmedAPIKey.isEmpty, ready: "Ready to search", pending: "Needed to search the Workshop")
        } header: {
            Text("Step 1 · Search the Workshop")
        } footer: {
            Text("Steam only uses this key to list wallpapers; it cannot download anything.")
        }

        Section {
            HStack {
                if !account.isInstalled {
                    Button(account.isInstalling ? "Installing the Steam downloader…" : "Install the Steam downloader") {
                        Task { await account.installDownloader() }
                    }
                    .disabled(account.isInstalling)
                    if account.isInstalling { ProgressView().controlSize(.small) }
                } else if let name = account.accountName {
                    status(done: true, ready: "Signed in as \(name)", pending: "")
                    Spacer()
                    Button("Sign out") { account.signOut() }
                } else {
                    Button("Sign in with Steam…") { account.signIn() }
                }
            }
            if let message = account.message {
                Text(message).font(.caption).foregroundStyle(.red)
            }
        } header: {
            Text("Step 2 · Download wallpapers")
        } footer: {
            Text(account.isInstalled
                 ? "Downloads use your Steam account, which must own Wallpaper Engine. Scan a QR code with the Steam app once; Livewall never sees your password."
                 : "First install DepotDownloader (about 80 MB, open source, from GitHub). It downloads Workshop items with your Steam account.")
        }
    }

    private func status(done: Bool, ready: LocalizedStringKey, pending: LocalizedStringKey) -> some View {
        Label(done ? ready : pending, systemImage: done ? "checkmark.circle.fill" : "circle.dashed")
            .foregroundStyle(done ? .green : .secondary)
    }
}
