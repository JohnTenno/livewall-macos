import SwiftUI

/// Red-tinted glass strip shown above a tab's content when something failed.
struct ErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .glassEffect(.regular.tint(.red.opacity(0.2)), in: .rect(cornerRadius: 12))
            .padding([.horizontal, .top], 10)
    }
}
