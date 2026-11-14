import SwiftUI
import UniformTypeIdentifiers

/// Browses static cards and plays only the selected wallpaper in the inspector.
struct LibraryView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: WallpaperLibrary
    @EnvironmentObject private var desktop: DesktopController
    @StateObject private var model = LibraryViewModel()
    @State private var previewID: UUID?
    @State private var showsPreview = true
    @State private var search = ""
    @State private var pendingRemoval: Wallpaper?

    private let columns = [GridItem(.adaptive(minimum: 155, maximum: 240), spacing: 12)]

    private static let importTypes: [UTType] = [.movie, .mpeg4Movie, .quickTimeMovie, .html, .folder]
        + [UTType(filenameExtension: "metal")].compactMap { $0 }

    var body: some View {
        VStack(spacing: 0) {
            if let error = desktop.lastError {
                ErrorBanner(message: error)
            }

            HSplitView {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                        TextField("Search your wallpapers", text: $search)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("library.search")
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(.background)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            gallery("My wallpapers", wallpapers: filtered(library.userWallpapers))
                            gallery("Built-in", wallpapers: filtered(BuiltInShaders.wallpapers))
                        }
                        .padding(16)
                    }
                }
                .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)

                if showsPreview {
                    if let wallpaper = previewID.flatMap({ library.wallpaper(id: $0) }) {
                        WallpaperInspector(wallpaper: wallpaper, onClose: { showsPreview = false },
                            onRemove: wallpaper.isBuiltIn ? nil : { pendingRemoval = wallpaper })
                            .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
                    } else {
                        VStack(spacing: 0) {
                            InspectorHeader(title: "Preview", onClose: { showsPreview = false })
                            ContentUnavailableView("Select a wallpaper", systemImage: "play.rectangle",
                                description: Text("Choose a card to play its preview here."))
                                .frame(maxHeight: .infinity)
                        }
                        .background(.background.secondary)
                        .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
                    }
                }
            }
        }
        .background(.background)
        .onAppear { repairSelection() }
        .onChange(of: library.wallpapers.map(\.id)) { repairSelection() }
        .toolbar {
            ToolbarItemGroup {
                Button("Reload", systemImage: "arrow.clockwise") { desktop.reload() }
                    .help("Restart the active wallpaper on every display")
                Button("Website…", systemImage: "globe") { model.isAddingWebsite = true }
                    .help("Use a web page (http or https address) as wallpaper")
                Button("Import…", systemImage: "plus") { model.isImporting = true }
                    .help("Add videos, HTML pages, folders with index.html or .metal shaders")
                Button("Preview", systemImage: "sidebar.right") { showsPreview.toggle() }
                    .help(showsPreview ? "Hide the preview panel" : "Show the preview panel")
                    .accessibilityIdentifier("library.togglePreview")
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
        .alert("Delete wallpaper?", isPresented: Binding(
            get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }
        ), presenting: pendingRemoval) { wallpaper in
            Button("Delete", role: .destructive) {
                model.remove(wallpaper, library: library, settings: settings)
                pendingRemoval = nil
                repairSelection()
            }
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
        } message: { wallpaper in
            Text("“\(wallpaper.name)” and its imported files will be removed from your library.")
        }
    }

    private func gallery(_ title: String, wallpapers: [Wallpaper]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text(wallpapers.count.formatted()).font(.caption).monospacedDigit()
            }
            .foregroundStyle(.secondary)

            if wallpapers.isEmpty {
                Text(search.isEmpty ? "Import a video, web wallpaper or shader to add it here." : "No matching wallpapers.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 90, alignment: .center)
                    .padding(12)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(wallpapers) { wallpaper in
                        WallpaperCard(wallpaper: wallpaper, isSelected: previewID == wallpaper.id,
                            isActive: settings.selectedWallpaperID == wallpaper.id,
                            onSelect: { previewID = wallpaper.id; showsPreview = true },
                            onApply: { settings.selectedWallpaperID = wallpaper.id },
                            onRemove: wallpaper.isBuiltIn ? nil : { pendingRemoval = wallpaper })
                    }
                }
            }
        }
    }

    private func filtered(_ wallpapers: [Wallpaper]) -> [Wallpaper] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? wallpapers : wallpapers.filter { $0.name.localizedStandardContains(query) }
    }

    private func repairSelection() {
        if let previewID, library.wallpaper(id: previewID) != nil { return }
        previewID = settings.selectedWallpaperID.flatMap { library.wallpaper(id: $0)?.id }
            ?? library.userWallpapers.first?.id ?? BuiltInShaders.wallpapers.first?.id
    }
}
