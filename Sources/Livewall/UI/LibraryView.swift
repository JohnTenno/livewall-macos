import SwiftUI
import UniformTypeIdentifiers

/// Lists every wallpaper and lets the user apply, import, or remove them.
struct LibraryView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: WallpaperLibrary
    @EnvironmentObject private var desktop: DesktopController

    @StateObject private var model = LibraryViewModel()

    private static let importTypes: [UTType] = [.movie, .mpeg4Movie, .quickTimeMovie, .html, .folder]
        + [UTType(filenameExtension: "metal")].compactMap { $0 }

    var body: some View {
        VStack(spacing: 0) {
            if let error = desktop.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.red.opacity(0.1))
            }

            List {
                Section("Incluidos") {
                    ForEach(BuiltInShaders.wallpapers) { row(for: $0) }
                }
                Section("Mis fondos") {
                    if library.userWallpapers.isEmpty {
                        Text("Importa un video, una página HTML, una carpeta con index.html o un shader .metal.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(library.userWallpapers) { row(for: $0) }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Recargar", systemImage: "arrow.clockwise") { desktop.reload() }
                Button("Sitio web…", systemImage: "globe") { model.isAddingWebsite = true }
                Button("Importar…", systemImage: "plus") { model.isImporting = true }
            }
        }
        .fileImporter(isPresented: $model.isImporting, allowedContentTypes: Self.importTypes, allowsMultipleSelection: true) { result in
            model.importFiles(result, library: library, settings: settings)
        }
        .sheet(isPresented: $model.isAddingWebsite) {
            AddWebsiteSheet()
        }
        .alert("No se pudo importar", isPresented: Binding(get: { model.importError != nil }, set: { if !$0 { model.importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.importError ?? "")
        }
    }

    private func row(for wallpaper: Wallpaper) -> some View {
        WallpaperRow(
            wallpaper: wallpaper,
            isSelected: settings.selectedWallpaperID == wallpaper.id,
            onApply: { settings.selectedWallpaperID = wallpaper.id },
            onRemove: wallpaper.isBuiltIn ? nil : { model.remove(wallpaper, library: library, settings: settings) }
        )
    }
}
