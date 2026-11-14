import SwiftUI
import AppKit

/// One live renderer, muted by default and released when the inspector disappears.
struct WallpaperLivePreview: View {
    let wallpaper: Wallpaper
    @EnvironmentObject private var library: WallpaperLibrary
    @StateObject private var player = WallpaperPreviewPlayer()

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black
                if let view = player.renderedView {
                    PreviewSurface(content: view, onVisibilityChange: player.setVisible)
                }
                if let error = player.error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle").font(.title2)
                        Text("Preview unavailable").font(.headline)
                        Text(error).font(.caption).multilineTextAlignment(.center)
                        Button("Try again") { player.load(wallpaper, library: library) }
                    }
                    .foregroundStyle(.white)
                    .padding(16)
                }
            }
            .frame(height: 220)
            .clipped()

            HStack(spacing: 4) {
                Button {
                    player.isPlaying.toggle()
                } label: {
                    Label(player.isPlaying ? "Pause" : "Play", systemImage: player.isPlaying ? "pause.fill" : "play.fill")
                        .frame(minWidth: 64, minHeight: 44)
                }
                .help("Pause or resume this preview")
                .accessibilityIdentifier("preview.playback")

                Spacer()

                Button {
                    player.isMuted.toggle()
                } label: {
                    Image(systemName: player.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(player.isMuted ? "Unmute preview" : "Mute preview")
                .help(player.isMuted ? "Unmute preview" : "Mute preview")
                .accessibilityIdentifier("preview.mute")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .background(.background.secondary)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .task(id: wallpaper) { player.load(wallpaper, library: library) }
        .onDisappear { player.tearDown() }
    }
}

private struct PreviewSurface: NSViewRepresentable {
    let content: NSView
    let onVisibilityChange: (Bool) -> Void

    func makeNSView(context: Context) -> PreviewSurfaceView {
        let view = PreviewSurfaceView()
        view.onVisibilityChange = onVisibilityChange
        view.install(content)
        return view
    }

    func updateNSView(_ view: PreviewSurfaceView, context: Context) {
        view.onVisibilityChange = onVisibilityChange
        view.install(content)
    }

    static func dismantleNSView(_ view: PreviewSurfaceView, coordinator: ()) {
        view.onVisibilityChange?(false)
        view.removeObservers()
    }
}

/// Keeps an offscreen or minimized preview from consuming rendering resources.
private final class PreviewSurfaceView: NSView {
    var onVisibilityChange: ((Bool) -> Void)?
    private weak var content: NSView?

    func install(_ view: NSView) {
        guard content !== view else { return }
        content?.removeFromSuperview()
        content = view
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        removeObservers()
        if let window {
            NotificationCenter.default.addObserver(self, selector: #selector(updateVisibility),
                name: NSWindow.didChangeOcclusionStateNotification, object: window)
            NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose),
                name: NSWindow.willCloseNotification, object: window)
        }
        updateVisibility()
    }

    @objc private func updateVisibility() {
        onVisibilityChange?(window?.occlusionState.contains(.visible) == true && !isHiddenOrHasHiddenAncestor)
    }

    @objc private func windowWillClose() { onVisibilityChange?(false) }

    func removeObservers() { NotificationCenter.default.removeObserver(self) }
}
