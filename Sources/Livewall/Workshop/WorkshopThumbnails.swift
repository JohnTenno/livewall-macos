import AppKit
import ImageIO

/// Downsamples and caches Workshop preview images in memory with a strict count limit (90) and cost limit (25 MB).
/// Scrolling or switching pages never leaks memory and auto-purges under system memory pressure.
@MainActor
final class WorkshopThumbnails {
    static let shared = WorkshopThumbnails()

    let countLimit: Int
    private let cache = NSCache<NSURL, NSImage>()
    private var pending: [URL: Task<NSImage?, Never>] = [:]
    private let session: URLSession

    nonisolated private static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = 16
        configuration.timeoutIntervalForRequest = 10
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: configuration)
    }()

    init(session: URLSession = WorkshopThumbnails.defaultSession, countLimit: Int = 90, totalCostLimit: Int = 25 * 1024 * 1024) {
        self.session = session
        self.countLimit = countLimit
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
    }

    func image(for url: URL?) async -> NSImage? {
        guard let url, ["https", "http"].contains(url.scheme?.lowercased() ?? "") else {
            return nil
        }

        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        let task: Task<NSImage?, Never>
        if let existing = pending[url] {
            task = existing
        } else {
            let session = self.session
            task = Task.detached(priority: .userInitiated) {
                guard let (data, response) = try? await session.data(from: url),
                      (response as? HTTPURLResponse)?.statusCode == 200 else {
                    return nil
                }
                guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                    return NSImage(data: data)
                }
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 360
                ]
                if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                    return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                }
                return NSImage(data: data)
            }
            pending[url] = task
        }

        let result = await task.value
        pending[url] = nil

        if let result {
            let cost = Int(result.size.width * result.size.height * 4)
            cache.setObject(result, forKey: url as NSURL, cost: cost)
        }

        return result
    }

    func cachedImage(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func clear() {
        cache.removeAllObjects()
    }
}
