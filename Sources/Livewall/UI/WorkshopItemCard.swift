import SwiftUI

struct WorkshopItemCard: View {
    let item: WorkshopItem
    let isDownloading: Bool
    let isImported: Bool
    let onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // A fill-scaled image overflows its frame, and clipping does not clip hit testing:
            // without allowsHitTesting(false) it swallows clicks on the buttons of the card above.
            Rectangle()
                .fill(.quaternary)
                .frame(height: 110)
                .frame(maxWidth: .infinity)
                .overlay {
                    AsyncImage(url: item.previewURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.clear
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(RoundedRectangle(cornerRadius: 8))

            Text(item.title)
                .font(.headline)
                .lineLimit(1)
                .help(item.title)

            HStack(spacing: 6) {
                if let type = item.type {
                    Text(type.displayName)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.tint.opacity(0.15), in: Capsule())
                }
                Text(ByteCountFormatter.string(fromByteCount: Int64(item.fileSize), countStyle: .file))
                Text("· \(item.subscriptions.formatted()) subs")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            HStack {
                actionButton
                Spacer()
                Link(destination: item.pageURL) {
                    Image(systemName: "arrow.up.right.square")
                }
                .help("Abrir en Steam")
            }
        }
        .padding(8)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var actionButton: some View {
        if isImported {
            Label("En la biblioteca", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.callout)
        } else if isDownloading {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Descargando…").font(.callout)
            }
        } else if item.type?.isSupported ?? false {
            Button("Descargar y aplicar", action: onDownload)
        } else {
            Text("No compatible").font(.callout).foregroundStyle(.secondary)
        }
    }
}
