import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: WallpaperLibrary

    @StateObject private var loginItem = LoginItemModel()

    var body: some View {
        Form {
            Section("Performance") {
                Toggle("Pause when a window covers the desktop", isOn: $settings.pauseWhenCovered)
                Toggle("Pause on battery", isOn: $settings.pauseOnBattery)
                Picker("Shader FPS", selection: $settings.frameRate) {
                    ForEach(AppSettings.frameRateOptions, id: \.self) { Text("\($0)").tag($0) }
                }
                Text("Also pauses when the screen is locked or off, and in Low Power Mode.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            SteamSettingsSection()

            Section("Audio") {
                Toggle("Mute videos and pages", isOn: $settings.muted)
            }

            Section("System") {
                Toggle("Open at login", isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.setEnabled($0) }))
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
}
