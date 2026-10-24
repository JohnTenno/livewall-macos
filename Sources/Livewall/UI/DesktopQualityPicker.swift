import SwiftUI

/// Chooses which file a video wallpaper plays on the desktop and reports the background optimization.
struct DesktopQualityPicker: View {
    let selection: DesktopVideoQuality
    let available: [DesktopVideoQuality]
    let progress: Double?
    let error: String?
    let onSelect: (DesktopVideoQuality) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let progress {
                HStack(spacing: 6) {
                    ProgressView(value: progress).frame(width: 90).controlSize(.small)
                    Text("Optimizing for your display… The original keeps playing meanwhile.")
                }
                .font(.caption).foregroundStyle(.secondary)
            } else if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            } else if available.count > 1 {
                Picker("Desktop", selection: Binding(get: { current }, set: onSelect)) {
                    ForEach(available) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.menu)
                .fixedSize()
                .controlSize(.small)
                .help(current.detail)
                Text(current.detail).font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("Already sized for your display; no lighter copy needed.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    /// Falls back to the original when the chosen copy does not exist.
    private var current: DesktopVideoQuality {
        available.contains(selection) ? selection : .original
    }
}
