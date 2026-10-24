import SwiftUI

struct LockScreenView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: WallpaperLibrary
    @EnvironmentObject private var lockScreen: LockScreenModel

    private var currentWallpaper: Wallpaper? {
        settings.selectedWallpaperID.flatMap(library.wallpaper(id:))
    }

    var body: some View {
        Form {
            Section("Aerial being replaced") {
                if let aerial = lockScreen.aerial {
                    LabeledContent("Aerial", value: aerial.name)
                    LabeledContent("Status", value: aerial.isDownloaded ? (lockScreen.hasBackup ? "Using Livewall video" : "Apple original") : "Not downloaded")
                } else {
                    Text("Choose an Aerial wallpaper in System Settings → Wallpaper, then come back here.")
                        .foregroundStyle(.secondary)
                }
                Button("Detect again") { lockScreen.refresh() }
                    .help("Read the Aerial currently selected in System Settings → Wallpaper")
            }

            Section("Use on lock screen") {
                if let wallpaper = currentWallpaper {
                    let alreadyApplied = lockScreen.isApplied(wallpaper)
                    Button(alreadyApplied ? "Already on lock screen" : "Use “\(wallpaper.name)” on lock screen") { lockScreen.apply(wallpaper) }
                        .buttonStyle(.glassProminent)
                        .disabled(alreadyApplied || lockScreen.isWorking || lockScreen.aerial == nil || wallpaper.kind == .web)
                    Text("Always uses the original imported file, never the lighter desktop copy. For the best result use a high-quality 4K 60 fps video: macOS plays it in slow motion when you lock and unlock, and low frame rates look choppy there.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("The first conversion to 4K HEVC takes several minutes. Saved conversions are reused when you apply the same wallpaper again. Deleting the wallpaper also deletes its saved conversions.")
                        .font(.caption).foregroundStyle(.secondary)
                    if wallpaper.kind == .web {
                        Text("Web wallpapers cannot be converted; use a video or a shader.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Choose a Livewall wallpaper first.").foregroundStyle(.secondary)
                }

                if lockScreen.isWorking {
                    if let progress = lockScreen.progress {
                        ProgressView(value: progress)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
                if let status = lockScreen.status {
                    Text(status).font(.callout)
                }
                if let error = lockScreen.error {
                    Text(error).font(.callout).foregroundStyle(.red)
                }
            }

            Section {
                Button("Restore original Aerial", role: .destructive) { lockScreen.restore() }
                    .disabled(!lockScreen.hasBackup || lockScreen.isWorking)
                Text("Livewall replaces the cached video of the selected Aerial and keeps the original. Shaders are recorded as a 30 s 4K loop.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { lockScreen.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            lockScreen.refresh()
        }
    }
}
