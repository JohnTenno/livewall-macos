import SwiftUI

struct MainWindowView: View {
    static let windowID = "main"

    var body: some View {
        TabView {
            Tab("Library", systemImage: "square.grid.2x2") {
                LibraryView()
            }
            Tab("Workshop", systemImage: "cloud") {
                WorkshopView()
            }
            Tab("Lock Screen", systemImage: "lock.display") {
                LockScreenView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .frame(minWidth: 760, minHeight: 520)
    }
}
