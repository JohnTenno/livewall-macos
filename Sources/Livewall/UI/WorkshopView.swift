import SwiftUI

/// Browses the Wallpaper Engine Workshop and downloads video/web items into the library.
struct WorkshopView: View {
    @EnvironmentObject private var workshop: WorkshopModel
    @EnvironmentObject private var account: SteamAccount

    private let columns = [GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            if let error = workshop.error {
                ErrorBanner(message: error)
            }

            if workshop.needsLogin {
                HStack {
                    Text("After logging in, press “Download and apply” again.")
                        .font(.callout)
                    Spacer()
                    Button("Log in to SteamCMD…") { account.openLoginTerminal() }
                }
                .padding(10)
            }

            if account.trimmedAPIKey.isEmpty {
                ContentUnavailableView("API key missing", systemImage: "key",
                                       description: Text("Add it in the Settings → Steam tab."))
            } else if workshop.items.isEmpty && !workshop.isLoading {
                ContentUnavailableView("Search wallpapers", systemImage: "magnifyingglass",
                                       description: Text("Only video and web wallpapers are shown, the ones Livewall can play."))
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
            TextField("Search the Workshop", text: $workshop.query.text)
                .textFieldStyle(.roundedBorder)
                .onSubmit { workshop.search() }
            Picker("Type", selection: $workshop.query.type) {
                Text("Video and web").tag(WorkshopItemType?.none)
                ForEach(WorkshopItemType.allCases.filter(\.isSupported)) { type in
                    Text(type.displayName).tag(Optional(type))
                }
            }
            .fixedSize()
            Picker("Sort", selection: $workshop.query.sort) {
                ForEach(WorkshopSort.allCases) { Text($0.displayName).tag($0) }
            }
            .fixedSize()
            Toggle("+18", isOn: $workshop.query.includeMature)
                .help("Include items marked as mature content")
            Button("Search", systemImage: "magnifyingglass") { workshop.search() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.glassProminent)
        }
        .labelsHidden()
        .padding(10)
        .glassEffect(in: .rect(cornerRadius: 16))
        .padding([.horizontal, .top], 10)
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
            Text("\(workshop.items.count) of \(workshop.total)")
                .font(.caption).foregroundStyle(.secondary).padding(.bottom, 8)
        }
    }
}
