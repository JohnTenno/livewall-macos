import SwiftUI

struct WorkshopItemCard: View {
    let item: WorkshopItem
    let isSelected: Bool
    let isDownloading: Bool
    let isImported: Bool
    let onSelect: () -> Void
    let onDownload: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 8) {
                    // Image overflow must not intercept neighboring cards' controls.
                    Rectangle()
                        .fill(.quaternary)
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .overlay {
                            AsyncImage(url: item.previewURL) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "photo").foregroundStyle(.secondary)
                            }
                            .allowsHitTesting(false)
                        }
                        .clipped()
                        .contentShape(Rectangle())

                    VStack(alignment: .leading, spacing: 6) {
                        if let type = item.type {
                            Text(type.displayName)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text(item.title)
                            .font(.headline)
                            .lineLimit(2).frame(height: 36, alignment: .topLeading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .help(item.title)
                        Text(ByteCountFormatter.string(fromByteCount: Int64(clamping: item.fileSize), countStyle: .file))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focused($focused)
            .accessibilityLabel("Preview " + item.title)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier("workshop.card." + item.id)

            HStack {
                actionButton
                Spacer()
                Link(destination: item.pageURL) {
                    Image(systemName: "arrow.up.right.square").frame(width: 44, height: 44)
                }
                .help("Open in Steam")
            }
            .padding(.horizontal, 10)
        }
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).strokeBorder(isSelected || focused ? Color.accentColor : .clear, lineWidth: 2)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isImported {
            Label("In library", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
        } else if isDownloading {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Downloading…").font(.callout)
            }
        } else if item.type?.isSupported ?? false {
            Button("Download", action: onDownload)
                .buttonStyle(.glass)
                .help("Download to your library without changing the desktop")
        } else {
            Text("Not supported").font(.callout).foregroundStyle(.secondary)
        }
    }
}
