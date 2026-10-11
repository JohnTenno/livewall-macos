import Foundation

/// Talks to the Steam Web API to browse the Wallpaper Engine Workshop.
final class SteamWorkshopClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(_ query: WorkshopQuery, apiKey: String, cursor: String = "*") async throws -> WorkshopPage {
        guard !apiKey.isEmpty else { throw WorkshopError.missingAPIKey }
        let (data, response) = try await session.data(from: query.url(apiKey: apiKey, cursor: cursor))
        if let status = (response as? HTTPURLResponse)?.statusCode, status != 200 {
            throw status == 401 || status == 403 ? WorkshopError.invalidAPIKey : WorkshopError.http(status)
        }
        return try WorkshopPage.decode(data)
    }
}
