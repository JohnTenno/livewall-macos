import SwiftUI

/// Menu shown from the menu bar icon: pause, options and updates.
struct MenuBarContent: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle("Pause", isOn: $settings.isPaused)
            .keyboardShortcut("p")

        Button("Options…") {
            openWindow(id: MainWindowView.windowID)
            NSApp.activate()
        }
        .keyboardShortcut("l")

        Divider()

        UpdateMenuItem()

        Button("Quit Livewall") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
