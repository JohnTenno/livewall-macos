import SwiftUI

struct MainWindowView: View {
    static let windowID = "main"

    var body: some View {
        TabView {
            Tab("Biblioteca", systemImage: "square.grid.2x2") {
                LibraryView()
            }
            Tab("Ajustes", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .frame(minWidth: 520, minHeight: 420)
    }
}
