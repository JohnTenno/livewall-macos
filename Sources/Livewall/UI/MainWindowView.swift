import SwiftUI

struct MainWindowView: View {
    static let windowID = "main"

    @EnvironmentObject private var library: WallpaperLibrary
    @EnvironmentObject private var lockScreen: LockScreenModel
    @EnvironmentObject private var steamAccount: SteamAccount
    @State private var tab = MainTab.library

    var body: some View {
        TabView(selection: $tab) {
            Tab("Library", systemImage: "square.grid.2x2", value: .library) {
                LibraryView()
            }
            Tab("Workshop", systemImage: "cloud", value: .workshop) {
                WorkshopView(openSettings: { tab = .settings })
            }
            Tab("Lock Screen", systemImage: "lock.display", value: .lockScreen) {
                LockScreenView()
            }
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                SettingsView()
            }
        }
        // Sidebar tabs get the system Liquid Glass sidebar, like System Settings.
        .tabViewStyle(.sidebarAdaptable)
        .frame(minWidth: 960, minHeight: 600)
        // Imports (file or Workshop) append to the library; offer the lock screen for each new video.
        .onChange(of: library.userWallpapers.count) { old, new in
            if new > old, let added = library.userWallpapers.last, added.kind == .video { lockScreen.offer = added }
        }
        .sheet(isPresented: Binding(get: { steamAccount.isSigningIn }, set: { if !$0 { steamAccount.cancelSignIn() } })) {
            SteamSignInSheet().environmentObject(steamAccount)
        }
        .alert("Also use it on the lock screen?", isPresented: Binding(
            get: { lockScreen.offer != nil }, set: { if !$0 { lockScreen.offer = nil } }
        ), presenting: lockScreen.offer) { wallpaper in
            Button("Use on lock screen") { lockScreen.apply(wallpaper) }
                .disabled(lockScreen.isWorking || lockScreen.aerial == nil)
            Button("Not now", role: .cancel) {}
        } message: { _ in
            Text(lockScreenOfferMessage)
        }
    }

    private var lockScreenOfferMessage: String {
        guard lockScreen.aerial != nil else {
            return String(localized: "First choose an Aerial in System Settings → Wallpaper; then use the Lock Screen tab.")
        }
        if lockScreen.isWorking { return String(localized: "Another lock screen conversion is running; use the Lock Screen tab when it finishes.") }
        return String(localized: "Recommended: the lock screen uses the original file at full quality, and macOS plays it in slow motion when you lock and unlock, so high-quality 4K 60 fps videos look best. Converting takes a few minutes; the desktop keeps using the lighter copy.")
    }
}
