import SwiftUI

/// Menu shown from the menu bar icon: quick wallpaper switch, pause and access to the library.
struct MenuBarContent: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: WallpaperLibrary
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Picker("Fondo", selection: $settings.selectedWallpaperID) {
            Text("Fondo del sistema").tag(UUID?.none)
            ForEach(library.wallpapers) { wallpaper in
                Label(wallpaper.name, systemImage: wallpaper.kind.systemImage).tag(Optional(wallpaper.id))
            }
        }
        .pickerStyle(.inline)

        Divider()

        Toggle("Pausar", isOn: $settings.isPaused)
            .keyboardShortcut("p")

        Button("Abrir biblioteca…") {
            openWindow(id: MainWindowView.windowID)
            NSApp.activate()
        }
        .keyboardShortcut("l")

        Divider()

        Button("Salir de Livewall") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
