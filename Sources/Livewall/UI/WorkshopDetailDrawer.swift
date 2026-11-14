import SwiftUI
import WebKit

struct YouTubePlayerView: NSViewRepresentable {
    let videoID: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsAirPlayForMediaPlayback = false
        let webView = WKWebView(frame: .zero, configuration: config)
        let embedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body { margin: 0; background-color: #000; overflow: hidden; }
          .container { position: relative; width: 100vw; height: 100vh; }
          iframe { width: 100%; height: 100%; border: none; }
        </style>
        </head>
        <body>
        <div class="container">
          <iframe src="https://www.youtube-nocookie.com/embed/\(videoID)?autoplay=1&mute=1&controls=1&loop=1&playlist=\(videoID)&modestbranding=1" allow="autoplay; encrypted-media" allowfullscreen></iframe>
        </div>
        </body>
        </html>
        """
        webView.loadHTMLString(embedHTML, baseURL: URL(string: "https://www.youtube-nocookie.com"))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

struct TagsFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }
        let height = currentY + rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }
    }
}

struct WorkshopDetailDrawer: View {
    let item: WorkshopItem
    let isDownloading: Bool
    let isImported: Bool
    let onClose: () -> Void
    let onDownload: () -> Void

    @State private var showVideo: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Wallpaper Details")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("Close")
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Preview (Video or Image)
                    mediaPreviewSection

                    // Title
                    Text(item.title)
                        .font(.title3.bold())
                        .textSelection(.enabled)

                    // Badges (Type, Resolution)
                    HStack(spacing: 8) {
                        if let type = item.type {
                            Text(type.displayName)
                                .font(.caption.bold())
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(.tint.opacity(0.18), in: Capsule())
                        }
                        if let resolution = item.resolution {
                            Text(resolution)
                                .font(.caption.bold())
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(.blue.opacity(0.18), in: Capsule())
                        }
                    }

                    // Key metrics
                    HStack(spacing: 16) {
                        Label(ByteCountFormatter.string(fromByteCount: Int64(item.fileSize), countStyle: .file),
                              systemImage: "internaldrive")
                        Label("\(item.subscriptions.formatted()) subscribers",
                              systemImage: "person.2")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    // Category Tags
                    if !item.categoryTags.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tags")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            TagsFlowLayout(spacing: 6) {
                                ForEach(item.categoryTags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                    }

                    // Description
                    if !item.shortDescription.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Description")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(item.shortDescription)
                                .font(.callout)
                                .foregroundStyle(.primary.opacity(0.9))
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(16)
            }

            Divider()

            // Action Buttons
            HStack(spacing: 12) {
                actionButton
                Spacer()
                Link(destination: item.pageURL) {
                    HStack(spacing: 4) {
                        Text("Steam")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.callout)
                }
                .buttonStyle(.glass)
                .help("Open in Steam")
            }
            .padding(16)
            .background(.ultraThinMaterial)
        }
        .frame(maxHeight: .infinity)
        .background(.background.secondary)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(.separator.opacity(0.5))
                .frame(width: 1)
        }
        .shadow(color: .black.opacity(0.25), radius: 16, x: -5, y: 0)
        .onAppear {
            showVideo = item.youTubeVideoID != nil
        }
    }

    @ViewBuilder
    private var mediaPreviewSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Rectangle()
                    .fill(.quaternary)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if showVideo, let videoID = item.youTubeVideoID {
                    YouTubePlayerView(videoID: videoID)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    AsyncImage(url: item.previewURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16/9, contentMode: .fit)

            if item.youTubeVideoID != nil {
                Picker("Preview Mode", selection: $showVideo) {
                    Text("Video Preview ▶").tag(true)
                    Text("Cover Image").tag(false)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isImported {
            Label("In library", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.headline)
        } else if isDownloading {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Downloading…").font(.headline)
            }
        } else if item.type?.isSupported ?? false {
            Button("Download and apply", action: onDownload)
                .buttonStyle(.glassProminent)
                .font(.headline)
        } else {
            Text("Not supported").font(.callout).foregroundStyle(.secondary)
        }
    }
}

