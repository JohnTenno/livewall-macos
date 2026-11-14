import SwiftUI

struct InspectorHeader: View {
    let title: String
    let onClose: () -> Void

    var body: some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark").frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Close preview")
            .accessibilityIdentifier("preview.close")
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }
}
