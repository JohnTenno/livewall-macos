import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: WallpaperLibrary

    @StateObject private var loginItem = LoginItemModel()

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $settings.pauseWhenCovered) {
                    Text("Pause when a window covers the desktop")
                    Text("Stops playback while the wallpaper is hidden. This saves the most CPU, GPU and battery.")
                }
                Toggle(isOn: $settings.pauseOnBattery) {
                    Text("Pause on battery")
                    Text("Freezes the wallpaper on its current frame while unplugged.")
                }
                Picker(selection: $settings.frameRate) {
                    ForEach(AppSettings.frameRateOptions, id: \.self) { Text("\($0) fps").tag($0) }
                } label: {
                    Text("Shader frame rate")
                    Text("Only affects shader wallpapers. Videos play at their own frame rate and web pages set their own. Lower values use less GPU.")
                }
                if let note = frameRateNote {
                    Label(note, systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.orange)
                }
            } header: {
                Text("Performance")
            } footer: {
                Text("Livewall always pauses when the screen is locked or off, and in Low Power Mode.")
            }

            Section {
                Label("Livewall is made for high-quality wallpapers: import the best version you have (4K, 60 fps). The original is never modified.", systemImage: "sparkles")
                Label("Desktop: Livewall makes lighter copies sized to your display in the background. Choose one under each video in the Library.", systemImage: "menubar.dock.rectangle")
                Label("“Optimized” looks the same as the original and uses less memory. “Battery saver (30 fps)” halves CPU and GPU use with slightly less smooth motion.", systemImage: "leaf")
                Label("Lock screen: always uses the original file, because macOS plays it in slow motion when you lock and unlock.", systemImage: "lock.display")
            } header: {
                Text("Video quality")
            }
            .font(.callout)

            SteamSettingsSection()

            Section("Audio") {
                Toggle(isOn: $settings.muted) {
                    Text("Mute videos and pages")
                    Text("With more than one display, only the main display plays sound.")
                }
            }

            Section("System") {
                Toggle(isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.setEnabled($0) })) {
                    Text("Open at login")
                    Text("Starts Livewall in the menu bar when you log in.")
                }
                if let loginError = loginItem.error {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                Button("Show library folder") {
                    NSWorkspace.shared.open(library.itemsURL)
                }
            }

            Section("Custom shaders") {
                Text("A .metal file must define:")
                Text("float4 wallpaper(float2 fragCoord, float2 resolution, float time, float2 mouse)")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Text("Pixel coordinates with the origin at the bottom left, like Shadertoy.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    /// Explains why the frame rate setting may not change anything for the active wallpaper.
    private var frameRateNote: String? {
        switch settings.selectedWallpaperID.flatMap(library.wallpaper(id:))?.kind {
        case .video: "Your active wallpaper is a video, so this setting does not change it. To make a video lighter, choose “Battery saver (30 fps)” under it in the Library."
        case .web: "Your active wallpaper is a web page; the page itself decides its frame rate."
        case .shader, nil: nil
        }
    }
}
