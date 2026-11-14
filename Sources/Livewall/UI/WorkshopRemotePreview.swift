import SwiftUI
import AppKit
import ImageIO
import WebKit

/// Loads only the author's small preview image, never the wallpaper package.
@MainActor
final class WorkshopPreviewImageLoader: ObservableObject {
    @Published private(set) var image: NSImage?
    @Published private(set) var frameCount = 0
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    private let session: URLSession
    private static let cache: NSCache<NSURL, NSData> = {
        let cache = NSCache<NSURL, NSData>()
        cache.totalCostLimit = 24 * 1024 * 1024
        return cache
    }()

    init(session: URLSession = .shared) { self.session = session }

    func load(_ url: URL?) async {
        image = nil
        error = nil
        frameCount = 0
        guard let url, ["https", "http"].contains(url.scheme?.lowercased() ?? "") else {
            error = "The author has not provided a preview image."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let data: Data
            if let cached = Self.cache.object(forKey: url as NSURL) {
                data = cached as Data
            } else {
                let (downloaded, response) = try await session.data(from: url)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                data = downloaded
                Self.cache.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
            }
            try Task.checkCancellation()
            let decoded = try Self.decode(data)
            image = decoded.image
            frameCount = decoded.frameCount
        } catch is CancellationError {
        } catch {
            if !Task.isCancelled { self.error = error.localizedDescription }
        }
    }

    /// Inspect the bytes, not the URL suffix: Steam's animated previews often have no extension.
    static func decode(_ data: Data) throws -> (image: NSImage, frameCount: Int) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = NSImage(data: data), CGImageSourceGetCount(source) > 0 else { throw URLError(.cannotDecodeContentData) }
        return (image, CGImageSourceGetCount(source))
    }
}

struct WorkshopRemotePreview: View {
    let url: URL?
    @StateObject private var loader = WorkshopPreviewImageLoader()
    @State private var isPlaying = true

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black
                if let image = loader.image {
                    AnimatedPreviewSurface(image: image, isPlaying: isPlaying)
                } else if loader.isLoading {
                    ProgressView().tint(.white)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "photo").font(.title)
                        Text("Preview unavailable").font(.headline)
                        Text(loader.error ?? "").font(.caption).multilineTextAlignment(.center)
                        if url != nil {
                            Button("Try again") { Task { await loader.load(url) } }
                        }
                    }
                    .foregroundStyle(.white).padding(16)
                }
            }
            .frame(height: 240)

            if loader.frameCount > 1 {
                HStack {
                    Button { isPlaying.toggle() } label: {
                        Label(isPlaying ? "Pause preview" : "Play preview", systemImage: isPlaying ? "pause.fill" : "play.fill")
                            .frame(minHeight: 36)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("workshop.preview.playback")
                    Spacer()
                    Text("Animated preview").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
            }
        }
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .task(id: url) { isPlaying = true; await loader.load(url) }
        .onDisappear { isPlaying = false }
    }
}

private struct AnimatedPreviewSurface: NSViewRepresentable {
    let image: NSImage
    let isPlaying: Bool

    func makeNSView(context: Context) -> VisibleAnimatedImageView {
        let view = VisibleAnimatedImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        return view
    }

    func updateNSView(_ view: VisibleAnimatedImageView, context: Context) {
        if view.image !== image { view.image = image }
        view.wantsAnimation = isPlaying
    }

    static func dismantleNSView(_ view: VisibleAnimatedImageView, coordinator: ()) {
        view.animates = false
        view.image = nil
        NotificationCenter.default.removeObserver(view)
    }
}

private final class VisibleAnimatedImageView: NSImageView {
    var wantsAnimation = true { didSet { updateAnimation() } }
    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric) }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)
        if let window {
            NotificationCenter.default.addObserver(self, selector: #selector(updateAnimation),
                name: NSWindow.didChangeOcclusionStateNotification, object: window)
        }
        updateAnimation()
    }

    @objc private func updateAnimation() {
        animates = wantsAnimation && window?.occlusionState.contains(.visible) == true
    }
}

/// YouTube previews are supplied by the author as additional Steam preview media.
struct WorkshopVideoPreview: NSViewRepresentable {
    let videoID: String

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.loadHTMLString("""
        <html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
        <body style="margin:0;background:#000"><iframe style="border:0;width:100%;height:100%"
        src="https://www.youtube-nocookie.com/embed/\(videoID)?rel=0&playsinline=1"
        allow="encrypted-media; picture-in-picture" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe></body></html>
        """, baseURL: URL(string: "https://steamcommunity.com"))
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {}

    static func dismantleNSView(_ view: WKWebView, coordinator: ()) {
        view.stopLoading()
        view.loadHTMLString("", baseURL: nil)
    }
}
