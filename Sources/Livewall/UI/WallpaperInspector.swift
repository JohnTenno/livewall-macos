import SwiftUI

struct WallpaperInspector: View {
    let wallpaper: Wallpaper
    let onClose: () -> Void
    let onRemove: (() -> Void)?
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: WallpaperLibrary
    @EnvironmentObject private var desktop: DesktopController
    @EnvironmentObject private var variants: DesktopVariantModel

    var body: some View {
        VStack(spacing: 0) {
            InspectorHeader(title: "Preview", onClose: onClose)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    WallpaperLivePreview(wallpaper: wallpaper)
                        .id(wallpaper.id)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(wallpaper.kind.displayName)
                            .font(.caption).foregroundStyle(.secondary)
                        Text(wallpaper.name)
                            .font(.title2.weight(.semibold)).textSelection(.enabled)
                        Text(sourceLabel).font(.callout).foregroundStyle(.secondary)
                            .lineLimit(3).textSelection(.enabled)
                    }

                    Button {
                        settings.selectedWallpaperID = wallpaper.id
                    } label: {
                        Label(isActive ? "Active on desktop" : "Apply to desktop", systemImage: isActive ? "checkmark" : "desktopcomputer")
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(isActive)
                    .accessibilityIdentifier("preview.apply")

                    if wallpaper.kind == .video, !wallpaper.isBuiltIn, case .libraryFile = wallpaper.source {
                        Divider()
                        Text("Desktop quality").font(.headline)
                        DesktopQualityPicker(selection: wallpaper.effectiveDesktopQuality,
                            available: variants.available(for: wallpaper), progress: variants.progress[wallpaper.id],
                            error: variants.errors[wallpaper.id]) { quality in
                                library.setDesktopQuality(quality, for: wallpaper)
                                if isActive { desktop.reload() }
                            }
                    }

                    if let onRemove {
                        Divider()
                        Button(role: .destructive, action: onRemove) {
                            Label("Delete wallpaper…", systemImage: "trash").frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(16)
            }
        }
        .background(.background.secondary)
    }

    private var isActive: Bool { settings.selectedWallpaperID == wallpaper.id }

    private var sourceLabel: String {
        switch wallpaper.source {
        case .builtInShader: String(localized: "Built-in wallpaper")
        case .libraryFile: String(localized: "In your library")
        case .remote(let url): url.absoluteString
        }
    }
}
