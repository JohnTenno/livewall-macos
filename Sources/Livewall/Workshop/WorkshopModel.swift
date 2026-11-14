import Foundation

/// Search results, paging and downloads for the Workshop tab.
@MainActor
final class WorkshopModel: ObservableObject {
    @Published var query = WorkshopQuery()
    @Published private(set) var pagination = WorkshopPagination()
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var downloading: Set<String> = []
    @Published private(set) var imported: Set<String> = []
    /// True after a download failed because SteamCMD has no cached Steam session.
    @Published private(set) var needsLogin = false

    private let client = SteamWorkshopClient()
    private let account: SteamAccount
    private let importer: WorkshopImporter
    private let settings: AppSettings
    private let library: WallpaperLibrary
    private var requestedPage = 1
    private var searchTask: Task<Void, Never>?
    private var cachedPreviewDetails: [String: WorkshopItem] = [:]
    private var searchGeneration = UUID()

    init(account: SteamAccount, library: WallpaperLibrary, settings: AppSettings) {
        self.account = account
        self.importer = WorkshopImporter(library: library)
        self.settings = settings
        self.library = library
        refreshImported()
    }

    var items: [WorkshopItem] { pagination.items }
    var total: Int? { pagination.total }
    var currentPage: Int { pagination.number }
    var canGoPrevious: Bool { !isLoading && pagination.hasPrevious }
    var canGoNext: Bool { !isLoading && pagination.hasNext }

    func previousPage() {
        guard canGoPrevious else { return }
        loadPage(currentPage - 1)
    }

    func nextPage() {
        guard canGoNext else { return }
        loadPage(currentPage + 1)
    }

    func retryPage() { loadPage(requestedPage) }

    func search() {
        searchTask?.cancel()
        searchGeneration = UUID()
        isLoading = false
        pagination = WorkshopPagination(pageSize: query.pageSize)
        loadPage(1)
    }

    private func loadPage(_ number: Int) {
        guard !isLoading else { return }
        requestedPage = number
        if pagination.showCachedPage(number) { error = nil; return }
        guard let cursor = pagination.cursor(for: number) else { return }
        let query = query
        let apiKey = account.trimmedAPIKey
        let generation = searchGeneration
        isLoading = true
        error = nil
        searchTask = Task {
            defer { if generation == searchGeneration { isLoading = false } }
            do {
                let page = try await client.search(query, apiKey: apiKey, cursor: cursor)
                guard !Task.isCancelled, generation == searchGeneration else { return }
                pagination.receive(page, number: number, cursor: cursor)
            } catch is CancellationError {
            } catch {
                if !Task.isCancelled, generation == searchGeneration { self.error = error.localizedDescription }
            }
        }
    }

    func refreshImported() {
        imported = Set(library.userWallpapers.compactMap(\.workshopID))
    }

    /// Fetch supplementary preview media on selection, without downloading the item.
    func previewDetails(for item: WorkshopItem) async -> WorkshopItem {
        if let cached = cachedPreviewDetails[item.id] { return cached }
        do {
            let details = try await client.previewDetails(itemID: item.id, apiKey: account.trimmedAPIKey)
            try Task.checkCancellation()
            cachedPreviewDetails[item.id] = details
            return details
        } catch {
            return item
        }
    }

    func download(_ item: WorkshopItem, apply: Bool = true) {
        guard !downloading.contains(item.id) else { return }
        if let existing = library.userWallpapers.first(where: { $0.workshopID == item.id }) {
            if apply { settings.selectedWallpaperID = existing.id }
            return
        }
        downloading.insert(item.id)
        error = nil
        let steamCMD = account.steamCMD
        let username = account.trimmedUsername

        Task {
            defer { downloading.remove(item.id) }
            do {
                let folder = try await steamCMD.download(
                    itemID: item.id, appID: WorkshopQuery.wallpaperEngineAppID, username: username
                )
                let importedWallpaper = try importer.importItem(at: folder, fallbackTitle: item.title)
                let wallpaper = library.setWorkshopSource(id: item.id, previewURL: item.previewURL, for: importedWallpaper)
                needsLogin = false
                imported.insert(item.id)
                if apply { settings.selectedWallpaperID = wallpaper.id }
            } catch WorkshopError.notLoggedIn {
                needsLogin = true
                self.error = WorkshopError.notLoggedIn.localizedDescription
            } catch {
                self.error = "\(item.title): \(error.localizedDescription)"
            }
        }
    }
}
