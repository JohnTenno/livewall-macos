import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: WallpaperLibrary

    @StateObject private var loginItem = LoginItemModel()

    var body: some View {
        Form {
            Section("Rendimiento") {
                Toggle("Pausar cuando una ventana tapa el escritorio", isOn: $settings.pauseWhenCovered)
                Toggle("Pausar con batería", isOn: $settings.pauseOnBattery)
                Picker("FPS de shaders", selection: $settings.frameRate) {
                    ForEach(AppSettings.frameRateOptions, id: \.self) { Text("\($0)").tag($0) }
                }
                Text("También se pausa con la pantalla bloqueada o apagada y en Modo de bajo consumo.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Audio") {
                Toggle("Silenciar videos y páginas", isOn: $settings.muted)
            }

            Section("Sistema") {
                Toggle("Abrir al iniciar sesión", isOn: Binding(get: { loginItem.isEnabled }, set: { loginItem.setEnabled($0) }))
                if let loginError = loginItem.error {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                Button("Mostrar carpeta de la biblioteca") {
                    NSWorkspace.shared.open(library.itemsURL)
                }
            }

            Section("Shaders propios") {
                Text("Un archivo .metal debe definir:")
                Text("float4 wallpaper(float2 fragCoord, float2 resolution, float time, float2 mouse)")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Text("Coordenadas en píxeles con origen abajo a la izquierda, como en Shadertoy.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
