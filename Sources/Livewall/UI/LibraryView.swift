import SwiftUI
import UniformTypeIdentifiers

/// Lists every wallpaper and lets the user apply, import, or remove them.
struct LibraryView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: WallpaperLibrary
    @EnvironmentObject private var desktop: DesktopController
    @EnvironmentObject private var variants: DesktopVariantModel

    @StateObject private var model = LibraryViewModel()

    private static let importTypes: [UTType] = [.movie, .mpeg4Movie, .quickTimeMovie, .html, .folder]
        + [UTType(filenameExtension: "metal")].compactMap { $0 }

    var body: some View {
        VStack(spacing: 0) {
            if let error = desktop.lastError {
                ErrorBanner(message: error)
            }

            List {
                Section("Built-in") {
                    ForEach(BuiltInShaders.wallpapers) { row(for: $0) }
                }
                Section("My wallpapers") {
                    if library.userWallpapers.isEmpty {
                        Text("Import a video, an HTML page, a folder with index.html or a .metal shader.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(library.userWallpapers) { row(for: $0) }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Reload", systemImage: "arrow.clockwise") { desktop.reload() }
                    .help("Restart the active wallpaper on every display")
                Button("Website…", systemImage: "globe") { model.isAddingWebsite = true }
                    .help("Use a web page (http or https address) as wallpaper")
                Button("Import…", systemImage: "plus") { model.isImporting = true }
                    .help("Add videos, HTML pages, folders with index.html or .metal shaders")
            }
        }
        .fileImporter(isPresented: $model.isImporting, allowedContentTypes: Self.importTypes, allowsMultipleSelection: true) { result in
            model.importFiles(result, library: library, settings: settings)
        }
        .sheet(isPresented: $model.isAddingWebsite) {
            AddWebsiteSheet()
        }
        .alert("Import failed", isPresented: Binding(get: { model.importError != nil }, set: { if !$0 { model.importError = nil } })) {
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
        ) {
            if wallpaper.kind == .video, !wallpaper.isBuiltIn, case .libraryFile = wallpaper.source {
                DesktopQualityPicker(
                    selection: wallpaper.effectiveDesktopQuality,
                    available: variants.available(for: wallpaper),
                    progress: variants.progress[wallpaper.id],
                    error: variants.errors[wallpaper.id]
                ) { quality in
                    library.setDesktopQuality(quality, for: wallpaper)
                    if settings.selectedWallpaperID == wallpaper.id { desktop.reload() }
                }
            }
        }
    }
}
