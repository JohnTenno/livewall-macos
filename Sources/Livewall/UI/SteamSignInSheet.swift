import SwiftUI

/// Shows the QR code to scan with the Steam mobile app; closes itself once Steam approves it.
struct SteamSignInSheet: View {
    @EnvironmentObject private var account: SteamAccount

    var body: some View {
        VStack(spacing: 16) {
            Text("Sign in with Steam").font(.title2.bold())
            Group {
                if let code = account.qrCode {
                    SteamQRCodeView(code: code)
                } else {
                    ProgressView("Connecting to Steam…")
                }
            }
            .frame(width: 260, height: 260)
            Text("Open the Steam app on your phone, tap the shield (Steam Guard) and scan this code.")
                .font(.callout).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Cancel", role: .cancel) { account.cancelSignIn() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(24)
        .frame(width: 360)
    }
}
