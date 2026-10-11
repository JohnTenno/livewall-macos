import SwiftUI

struct MainWindowView: View {
    static let windowID = "main"

    var body: some View {
        TabView {
            Tab("Biblioteca", systemImage: "square.grid.2x2") {
                LibraryView()
            }
            Tab("Workshop", systemImage: "cloud") {
                WorkshopView()
            }
            Tab("Bloqueo", systemImage: "lock.display") {
                LockScreenView()
            }
            Tab("Ajustes", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .frame(minWidth: 760, minHeight: 520)
    }
}
