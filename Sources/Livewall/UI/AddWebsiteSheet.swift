import SwiftUI

struct AddWebsiteSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: WallpaperLibrary
    @Environment(\.dismiss) private var dismiss

    @StateObject private var form = WebsiteFormModel()

    var body: some View {
        Form {
            TextField("Address", text: $form.address)
            TextField("Nombre (opcional)", text: $form.name)
            if let error = form.error {
                Text(error).foregroundStyle(.red).font(.callout)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    if form.submit(library: library, settings: settings) { dismiss() }
                }
            }
        }
    }
}
