import SwiftUI

@main
struct LivewallApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Livewall", systemImage: "sparkles.tv") {
            MenuBarContent()
                .environmentObject(appDelegate.settings)
                .environmentObject(appDelegate.library)
        }

        Window("Livewall", id: MainWindowView.windowID) {
            MainWindowView()
                .environmentObject(appDelegate.settings)
                .environmentObject(appDelegate.library)
                .environmentObject(appDelegate.desktop)
                .environmentObject(appDelegate.lockScreen)
                .environmentObject(appDelegate.steamAccount)
                .environmentObject(appDelegate.workshop)
                .environmentObject(appDelegate.desktopVariants)
        }
        .defaultSize(width: 900, height: 640)
    }
}
