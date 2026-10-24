import AppKit
import WebKit

/// Shows a local HTML wallpaper or a remote page.
/// Pages can listen for `livewall-pause` / `livewall-play` window events to stop their own animation loops.
@MainActor
final class WebRenderer: NSObject, WallpaperRenderer, WKNavigationDelegate {
    let view: NSView
    private let webView: WKWebView
    private var muted: Bool
    private var playing = false

    init(url: URL, options: RenderOptions) {
        muted = options.muted
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let scripts = configuration.userContentController
        scripts.addUserScript(WKUserScript(source: Self.mediaScript(muted: options.muted), injectionTime: .atDocumentStart, forMainFrameOnly: false))
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
        super.init()
        webView.navigationDelegate = self

        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: url))
        }
    }

    func update(options: RenderOptions) {
        guard muted != options.muted else { return }
        muted = options.muted
        applyMute()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        applyMute()
        if playing { play() } else { pause() }
    }

    private func applyMute() {
        webView.evaluateJavaScript("window.postMessage({livewallMuted: \(muted)}, '*')")
    }

    func play() {
        playing = true
        webView.setAllMediaPlaybackSuspended(false)
        dispatch(event: "livewall-play")
    }

    func pause() {
        playing = false
        webView.setAllMediaPlaybackSuspended(true)
        dispatch(event: "livewall-pause")
    }

    func tearDown() {
        webView.navigationDelegate = nil
        webView.setAllMediaPlaybackSuspended(true)
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
    }

    /// Visit only newly inserted subtrees, not the entire document on every DOM mutation.
    private static func mediaScript(muted: Bool) -> String {
        """
        (() => {
          let muted = \(muted);
          const originalMute = new WeakMap();
          const applyMedia = m => {
            if (muted) {
              if (!originalMute.has(m)) originalMute.set(m, m.muted);
              m.muted = true;
            } else if (originalMute.has(m)) {
              m.muted = originalMute.get(m);
              originalMute.delete(m);
            }
          };
          const apply = root => {
            if (root.matches?.('video, audio')) applyMedia(root);
            root.querySelectorAll?.('video, audio').forEach(applyMedia);
          };
          new MutationObserver(records => records.forEach(record =>
            record.addedNodes.forEach(apply)
          )).observe(document, { childList: true, subtree: true });
          document.addEventListener('play', e => applyMedia(e.target), true);
          window.addEventListener('message', e => {
            if (e.data?.livewallRequestMute === true) {
              for (let i = 0; i < frames.length; i++) {
                if (e.source === frames[i]) e.source.postMessage({livewallMuted: muted}, '*');
              }
              return;
            }
            if (e.source !== window && e.source !== parent) return;
            if (typeof e.data?.livewallMuted !== 'boolean') return;
            muted = e.data.livewallMuted;
            apply(document);
            for (let i = 0; i < frames.length; i++) frames[i].postMessage({livewallMuted: muted}, '*');
          });
          if (parent !== window) parent.postMessage({livewallRequestMute: true}, '*');
        })();
        """
    }

    private func dispatch(event: String) {
        webView.evaluateJavaScript("window.dispatchEvent(new Event('\(event)'))")
    }
}
