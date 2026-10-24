import Foundation

/// Owns the user's imported wallpapers: copies files into Application Support and keeps a JSON index.
@MainActor
final class WallpaperLibrary: ObservableObject {
    @Published private(set) var userWallpapers: [Wallpaper] = []

    let rootURL: URL
    private let fileManager: FileManager

    var itemsURL: URL { rootURL.appending(path: "Items", directoryHint: .isDirectory) }
    private var indexURL: URL { rootURL.appending(path: "library.json") }

    var wallpapers: [Wallpaper] { BuiltInShaders.wallpapers + userWallpapers }

    nonisolated static var defaultRootURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Livewall", directoryHint: .isDirectory)
    }

    init(rootURL: URL = WallpaperLibrary.defaultRootURL, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: itemsURL, withIntermediateDirectories: true)
        load()
    }

    func wallpaper(id: UUID) -> Wallpaper? {
        wallpapers.first { $0.id == id }
    }

    /// Resolves a library-relative source to an absolute file URL.
    func fileURL(forRelativePath path: String) -> URL {
        itemsURL.appending(path: path)
    }

    /// Imports a video, HTML page, Metal shader, or a folder containing `index.html`.
    @discardableResult
    func importItem(at url: URL, name: String? = nil) throws -> Wallpaper {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let name = name ?? url.deletingPathExtension().lastPathComponent
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        if isDirectory {
            return try importWebFolder(at: url, entryFile: "index.html", name: name)
        }

        guard let kind = WallpaperKind(fileExtension: url.pathExtension) else {
            throw LibraryError.unsupportedFile(url.pathExtension)
        }
        let id = UUID()
        let fileName = "\(id.uuidString).\(url.pathExtension.lowercased())"
        try fileManager.copyItem(at: url, to: itemsURL.appending(path: fileName))
        return add(Wallpaper(id: id, name: name, kind: kind, source: .libraryFile(fileName)))
    }

    /// Copies a whole site folder; `entryFile` is the page to load, relative to the folder.
    @discardableResult
    func importWebFolder(at folder: URL, entryFile: String, name: String) throws -> Wallpaper {
        guard fileManager.fileExists(atPath: folder.appending(path: entryFile).path) else {
            throw LibraryError.missingIndex
        }
        let id = UUID()
        try fileManager.copyItem(at: folder, to: itemsURL.appending(path: id.uuidString, directoryHint: .isDirectory))
        return add(Wallpaper(id: id, name: name, kind: .web, source: .libraryFile("\(id.uuidString)/\(entryFile)")))
    }

    private func add(_ wallpaper: Wallpaper) -> Wallpaper {
        userWallpapers.append(wallpaper)
        save()
        return wallpaper
    }

    @discardableResult
    func addWebsite(_ address: String, name: String) throws -> Wallpaper {
        guard let url = URL(string: address.trimmingCharacters(in: .whitespaces)),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme), url.host != nil
        else { throw LibraryError.invalidURL }

        let title = name.trimmingCharacters(in: .whitespaces)
        return add(Wallpaper(id: UUID(), name: title.isEmpty ? url.host ?? address : title, kind: .web, source: .remote(url)))
    }

    func rename(_ wallpaper: Wallpaper, to name: String) {
        guard let index = userWallpapers.firstIndex(where: { $0.id == wallpaper.id }) else { return }
        userWallpapers[index].name = name
        save()
    }

    func remove(_ wallpaper: Wallpaper) {
        guard let index = userWallpapers.firstIndex(where: { $0.id == wallpaper.id }) else { return }
        if case .libraryFile(let path) = wallpaper.source, let topLevel = path.split(separator: "/").first {
            try? fileManager.removeItem(at: itemsURL.appending(path: String(topLevel)))
        }
        LockScreenExportCache(libraryRoot: rootURL).remove(wallpaperID: wallpaper.id)
        userWallpapers.remove(at: index)
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        userWallpapers = (try? JSONDecoder().decode([Wallpaper].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(userWallpapers) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
