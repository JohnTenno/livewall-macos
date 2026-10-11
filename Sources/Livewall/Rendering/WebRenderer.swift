import AppKit
import WebKit

/// Shows a local HTML wallpaper or a remote page.
/// Pages can listen for `livewall-pause` / `livewall-play` window events to stop their own animation loops.
@MainActor
final class WebRenderer: WallpaperRenderer {
    let view: NSView
    private let webView: WKWebView

    init(url: URL, options: RenderOptions) {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let scripts = configuration.userContentController
        if options.muted {
            scripts.addUserScript(WKUserScript(source: Self.muteScript, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        }
        scripts.addUserScript(WKUserScript(source: WallpaperEngineShim.stubs, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        if url.isFileURL, let project = try? WallpaperEngineProject.load(from: url.deletingLastPathComponent()) {
            scripts.addUserScript(WKUserScript(
                source: WallpaperEngineShim.applyProperties(project.defaultPropertiesJSON()),
                injectionTime: .atDocumentEnd, forMainFrameOnly: true
            ))
        }
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.underPageBackgroundColor = .black
        view = webView

        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: url))
        }
    }

    func play() {
        webView.setAllMediaPlaybackSuspended(false)
        dispatch(event: "livewall-play")
    }

    func pause() {
        webView.setAllMediaPlaybackSuspended(true)
        dispatch(event: "livewall-pause")
    }

    func tearDown() {
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
    }

    /// WKWebView has no public mute switch, so mute every media element, including ones added later.
    private static let muteScript = """
    (() => {
      const mute = (root) => root.querySelectorAll('video, audio').forEach((m) => { m.muted = true; });
      new MutationObserver(() => mute(document)).observe(document, { childList: true, subtree: true });
      document.addEventListener('play', (e) => { e.target.muted = true; }, true);
    })();
    """

    private func dispatch(event: String) {
        webView.evaluateJavaScript("window.dispatchEvent(new Event('\(event)'))")
    }
}
