import SwiftUI

struct WallpaperRow: View {
    let wallpaper: Wallpaper
    let isSelected: Bool
    let onApply: () -> Void
    let onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: wallpaper.kind.systemImage)
                .font(.title2)
                .frame(width: 32)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(wallpaper.name).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }

            Spacer()

            if isSelected {
                Label("Active", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(Color.accentColor)
            } else {
                Button("Apply", action: onApply)
            }

            if let onRemove {
                Button("Delete", systemImage: "trash", role: .destructive, action: onRemove)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onApply)
    }

    private var subtitle: String {
        switch wallpaper.source {
        case .builtInShader: "\(wallpaper.kind.displayName) · built-in"
        case .remote(let url): "\(wallpaper.kind.displayName) · \(url.absoluteString)"
        case .libraryFile: wallpaper.kind.displayName
        }
    }
}
