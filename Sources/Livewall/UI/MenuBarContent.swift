import SwiftUI

/// Menu shown from the menu bar icon: quick wallpaper switch, pause and access to the library.
struct MenuBarContent: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: WallpaperLibrary
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Picker("Wallpaper", selection: $settings.selectedWallpaperID) {
            Text("System wallpaper").tag(UUID?.none)
            ForEach(library.wallpapers) { wallpaper in
                Label(wallpaper.name, systemImage: wallpaper.kind.systemImage).tag(Optional(wallpaper.id))
            }
        }
        .pickerStyle(.inline)

        Divider()

        Toggle("Pause", isOn: $settings.isPaused)
            .keyboardShortcut("p")

        Button("Open library…") {
            openWindow(id: MainWindowView.windowID)
            NSApp.activate()
        }
        .keyboardShortcut("l")

        Divider()

        Button("Quit Livewall") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
