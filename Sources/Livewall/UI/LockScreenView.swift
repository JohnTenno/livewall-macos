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
            Section("Aerial que se reemplaza") {
                if let aerial = lockScreen.aerial {
                    LabeledContent("Aerial", value: aerial.name)
                    LabeledContent("Estado", value: aerial.isDownloaded ? (lockScreen.hasBackup ? "Usando video de Livewall" : "Original de Apple") : "Sin descargar")
                } else {
                    Text("Elige un fondo Aerial en Ajustes del Sistema → Fondo de pantalla y vuelve aquí.")
                        .foregroundStyle(.secondary)
                }
                Button("Volver a detectar") { lockScreen.refresh() }
            }

            Section("Usar en la pantalla de bloqueo") {
                if let wallpaper = currentWallpaper {
                    Button("Usar «\(wallpaper.name)» en la pantalla de bloqueo") { lockScreen.apply(wallpaper) }
                        .disabled(lockScreen.isWorking || lockScreen.aerial == nil || wallpaper.kind == .web)
                    if wallpaper.kind == .web {
                        Text("Los fondos web no se pueden convertir; usa un video o un shader.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Primero elige un fondo de Livewall.").foregroundStyle(.secondary)
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
                Button("Restaurar Aerial original", role: .destructive) { lockScreen.restore() }
                    .disabled(!lockScreen.hasBackup || lockScreen.isWorking)
                Text("Livewall reemplaza el video en caché del Aerial elegido y guarda el original. Los shaders se graban como un loop de 30 s en 4K.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { lockScreen.refresh() }
    }
}
