import SwiftUI

/// Browses the Wallpaper Engine Workshop and downloads video/web items into the library.
struct WorkshopView: View {
    @EnvironmentObject private var workshop: WorkshopModel
    @EnvironmentObject private var account: SteamAccount

    private let columns = [GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()

            if let error = workshop.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.red.opacity(0.1))
            }

            if account.trimmedAPIKey.isEmpty {
                ContentUnavailableView("Falta la API key", systemImage: "key",
                                       description: Text("Agrégala en la pestaña Ajustes → Steam."))
            } else if workshop.items.isEmpty && !workshop.isLoading {
                ContentUnavailableView("Busca fondos", systemImage: "magnifyingglass",
                                       description: Text("Solo se muestran fondos de video y web, los que Livewall puede reproducir."))
            } else {
                results
            }
        }
        .onAppear {
            if workshop.items.isEmpty && !account.trimmedAPIKey.isEmpty { workshop.search() }
        }
    }

    private var searchBar: some View {
        HStack {
            TextField("Buscar en el Workshop", text: $workshop.query.text)
                .textFieldStyle(.roundedBorder)
                .onSubmit { workshop.search() }
            Picker("Tipo", selection: $workshop.query.type) {
                Text("Video y web").tag(WorkshopItemType?.none)
                ForEach(WorkshopItemType.allCases.filter(\.isSupported)) { type in
                    Text(type.displayName).tag(Optional(type))
                }
            }
            .fixedSize()
            Picker("Orden", selection: $workshop.query.sort) {
                ForEach(WorkshopSort.allCases) { Text($0.displayName).tag($0) }
            }
            .fixedSize()
            Toggle("+18", isOn: $workshop.query.includeMature)
            Button("Buscar", systemImage: "magnifyingglass") { workshop.search() }
                .keyboardShortcut(.defaultAction)
        }
        .labelsHidden()
        .padding(10)
        .onChange(of: workshop.query.type) { workshop.search() }
        .onChange(of: workshop.query.sort) { workshop.search() }
        .onChange(of: workshop.query.includeMature) { workshop.search() }
    }

    private var results: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(workshop.items) { item in
                    WorkshopItemCard(
                        item: item,
                        isDownloading: workshop.downloading.contains(item.id),
                        isImported: workshop.imported.contains(item.id),
                        onDownload: { workshop.download(item) }
                    )
                    .onAppear {
                        if item.id == workshop.items.last?.id && workshop.canLoadMore { workshop.loadMore() }
                    }
                }
            }
            .padding(12)

            if workshop.isLoading {
                ProgressView().padding()
            }
            Text("\(workshop.items.count) de \(workshop.total)")
                .font(.caption).foregroundStyle(.secondary).padding(.bottom, 8)
        }
    }
}
