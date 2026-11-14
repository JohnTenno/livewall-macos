import SwiftUI

struct WorkshopInspector: View {
    let item: WorkshopItem
    let onClose: () -> Void
    @EnvironmentObject private var workshop: WorkshopModel
    @EnvironmentObject private var library: WallpaperLibrary
    @EnvironmentObject private var settings: AppSettings
    @State private var showsVideo = false
    @State private var details: WorkshopItem?

    var body: some View {
        VStack(spacing: 0) {
            InspectorHeader(title: "Workshop preview", onClose: onClose)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let wallpaper = localWallpaper {
                        WallpaperLivePreview(wallpaper: wallpaper).id(wallpaper.id)
                    } else {
                        if let videoID = (details ?? item).youtubePreviewID {
                            Picker("Preview", selection: $showsVideo) {
                                Text("Image").tag(false)
                                Text("Video").tag(true)
                            }
                            .pickerStyle(.segmented)
                            if showsVideo {
                                WorkshopVideoPreview(videoID: videoID)
                                    .frame(height: 240)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        if !showsVideo {
                            WorkshopRemotePreview(url: details?.previewURL ?? item.previewURL)
                        }
                    }

                    Text(item.title).font(.title2.weight(.semibold)).textSelection(.enabled)

                    VStack(spacing: 8) {
                        LabeledContent("Type", value: item.type?.displayName ?? "Unknown")
                        LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: Int64(clamping: item.fileSize), countStyle: .file))
                    }
                    .font(.callout)

                    action

                    if !item.shortDescription.isEmpty {
                        Text(item.shortDescription).font(.callout).textSelection(.enabled)
                    }
                    if !item.tags.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], alignment: .leading) {
                            ForEach(Array(Set(item.tags)).sorted(), id: \.self) { tag in
                                Text(tag).font(.caption).lineLimit(2)
                                    .padding(6).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    Link(destination: item.pageURL) {
                        Label("Open in Steam", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.glass)
                }
                .padding(16)
            }
        }
        .background(.background.secondary)
        .task(id: item.id) { details = await workshop.previewDetails(for: item) }
    }

    private var localWallpaper: Wallpaper? {
        library.userWallpapers.first { $0.workshopID == item.id }
    }

    @ViewBuilder private var action: some View {
        if let wallpaper = localWallpaper {
            let active = settings.selectedWallpaperID == wallpaper.id
            Button { settings.selectedWallpaperID = wallpaper.id } label: {
                Label(active ? "Active on desktop" : "Apply to desktop", systemImage: active ? "checkmark" : "desktopcomputer")
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.glassProminent)
            .disabled(active)
        } else if workshop.downloading.contains(item.id) {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Downloading…")
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        } else {
            Button { workshop.download(item, apply: false) } label: {
                Label("Download to library", systemImage: "arrow.down.to.line")
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.glassProminent)
            .disabled(!(item.type?.isSupported ?? false))
        }
    }

}
