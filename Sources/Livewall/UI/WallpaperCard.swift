import SwiftUI

struct WallpaperCard: View {
    let wallpaper: Wallpaper
    let isSelected: Bool
    let isActive: Bool
    let onSelect: () -> Void
    let onApply: () -> Void
    let onRemove: (() -> Void)?

    @EnvironmentObject private var library: WallpaperLibrary
    @State private var thumbnail: NSImage?
    @FocusState private var focused: Bool

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                Rectangle()
                    .fill(.quaternary)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        if let thumbnail {
                            Image(nsImage: thumbnail).resizable().scaledToFill()
                        } else {
                            Image(systemName: wallpaper.kind.systemImage)
                                .font(.system(size: 32, weight: .light))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .clipped()
                    .overlay(alignment: .topLeading) {
                        if isActive {
                            Label("Active", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .foregroundStyle(.white)
                                .background(.tint, in: Capsule())
                                .padding(8)
                        }
                    }
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 5) {
                    Text(wallpaper.kind.displayName)
                        .font(.caption).foregroundStyle(.secondary)
                    Text(wallpaper.name)
                        .font(.headline)
                        .lineLimit(2).frame(height: 36, alignment: .topLeading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(10)
                .foregroundStyle(.primary)
                .background(.background.secondary)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12).strokeBorder(isSelected || focused ? Color.accentColor : .clear, lineWidth: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($focused)
        .accessibilityLabel(isActive ? String(localized: "\(wallpaper.name), \(wallpaper.kind.displayName), active") : "\(wallpaper.name), \(wallpaper.kind.displayName)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("wallpaper.card." + wallpaper.id.uuidString)
        .help("Click to preview; double-click to apply")
        .simultaneousGesture(TapGesture(count: 2).onEnded(onApply))
        .contextMenu {
            Button("Preview", systemImage: "play.rectangle", action: onSelect)
            Button("Apply to desktop", systemImage: "desktopcomputer", action: onApply)
            if let onRemove { Button("Delete wallpaper…", systemImage: "trash", role: .destructive, action: onRemove) }
        }
        .task(id: wallpaper) {
            let image = await WallpaperThumbnails.shared.image(for: wallpaper, library: library)
            if !Task.isCancelled { thumbnail = image }
        }
    }
}
