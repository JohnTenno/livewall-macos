import SwiftUI

/// Menu bar entry for updates: checks on demand and only installs after the user picks "Update to …".
struct UpdateMenuItem: View {
    @EnvironmentObject private var updater: AppUpdater

    var body: some View {
        switch updater.state {
        case .available(let version):
            Button("Update to \(version) and restart") { Task { await updater.install() } }
        case .checking:
            Text("Checking for updates…")
        case .installing:
            Text("Installing update…")
        case .failed(let message):
            Button("Update failed: \(message)") { Task { await updater.check() } }
        case .idle, .upToDate:
            Button("Check for updates") { Task { await updater.check() } }
        }
    }
}
