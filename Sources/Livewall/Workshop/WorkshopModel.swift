import Foundation

/// Search results, paging and downloads for the Workshop tab.
@MainActor
final class WorkshopModel: ObservableObject {
    @Published var query = WorkshopQuery()
    @Published private(set) var items: [WorkshopItem] = []
    @Published private(set) var total = 0
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var downloading: Set<String> = []
    @Published private(set) var imported: Set<String> = []

    private let client = SteamWorkshopClient()
    private let account: SteamAccount
    private let importer: WorkshopImporter
    private let settings: AppSettings
    private var nextCursor: String?
    private var searchTask: Task<Void, Never>?

    init(account: SteamAccount, library: WallpaperLibrary, settings: AppSettings) {
        self.account = account
        self.importer = WorkshopImporter(library: library)
        self.settings = settings
    }

    var canLoadMore: Bool { nextCursor != nil && items.count < total && !isLoading }

    func search() {
        searchTask?.cancel()
        items = []
        nextCursor = "*"
        loadMore()
    }

    func loadMore() {
        guard let cursor = nextCursor, !isLoading else { return }
        let query = query
        let apiKey = account.trimmedAPIKey
        isLoading = true
        error = nil
        searchTask = Task {
            defer { isLoading = false }
            do {
                let page = try await client.search(query, apiKey: apiKey, cursor: cursor)
                guard !Task.isCancelled else { return }
                let known = Set(items.map(\.id))
                items += page.items.filter { !known.contains($0.id) }
                total = page.total
                // Steam keeps returning the same cursor once the results run out.
                nextCursor = page.items.isEmpty || page.nextCursor == cursor ? nil : page.nextCursor
            } catch is CancellationError {
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    func download(_ item: WorkshopItem) {
        guard !downloading.contains(item.id) else { return }
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
                let wallpaper = try importer.importItem(at: folder, fallbackTitle: item.title)
                imported.insert(item.id)
                settings.selectedWallpaperID = wallpaper.id
            } catch {
                self.error = "\(item.title): \(error.localizedDescription)"
            }
        }
    }
}
