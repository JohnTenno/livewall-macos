import SwiftUI

/// Browses the Wallpaper Engine Workshop and downloads video/web items into the library.
struct WorkshopView: View {
    @EnvironmentObject private var workshop: WorkshopModel
    @EnvironmentObject private var account: SteamAccount
    @EnvironmentObject private var library: WallpaperLibrary

    @State private var previewItem: WorkshopItem?
    @State private var showsPreview = true

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

            HSplitView {
                Group {
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
                .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)

                if showsPreview {
                    if let item = previewItem {
                        WorkshopInspector(item: item, onClose: { showsPreview = false })
                            .id(item.id)
                            .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
                    } else {
                        VStack(spacing: 0) {
                            InspectorHeader(title: "Workshop preview", onClose: { showsPreview = false })
                            ContentUnavailableView("Select a wallpaper", systemImage: "play.rectangle",
                                description: Text("Choose a card to see its preview and details."))
                                .frame(maxHeight: .infinity)
                        }
                        .background(.background.secondary)
                        .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
                    }
                }
            }
        }
        .toolbar {
            Button("Preview", systemImage: "sidebar.right") { showsPreview.toggle() }
                .help(showsPreview ? "Hide the preview panel" : "Show the preview panel")
                .accessibilityIdentifier("workshop.togglePreview")
        }
        .onChange(of: library.userWallpapers) { workshop.refreshImported() }
        .onAppear {
            workshop.refreshImported()
            if workshop.items.isEmpty && !account.trimmedAPIKey.isEmpty { search() }
        }
    }

    private var searchBar: some View {
        HStack {
            TextField("Search the Workshop", text: $workshop.query.text)
                .textFieldStyle(.roundedBorder)
                .onSubmit { search() }
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
            Button("Search", systemImage: "magnifyingglass") { search() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.glassProminent)
        }
        .labelsHidden()
        .padding(10)
        .glassEffect(in: .rect(cornerRadius: 16))
        .padding([.horizontal, .top], 10)
        .onChange(of: workshop.query.type) { search() }
        .onChange(of: workshop.query.sort) { search() }
        .onChange(of: workshop.query.includeMature) { search() }
    }

    private var results: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(workshop.items) { item in
                            WorkshopItemCard(
                                item: item,
                                isSelected: previewItem?.id == item.id,
                                isDownloading: workshop.downloading.contains(item.id),
                                isImported: workshop.imported.contains(item.id),
                                onSelect: { previewItem = item; showsPreview = true },
                                onDownload: { workshop.download(item, apply: false) }
                            )
                        }
                    }
                    .id("workshop.grid")
                    .padding(12)

                    if workshop.isLoading {
                        ProgressView().padding()
                    } else if workshop.error != nil {
                        Button("Try loading again") { workshop.retryPage() }
                            .buttonStyle(.glass)
                            .padding(.bottom, 8)
                    }
                }
                .onChange(of: workshop.currentPage) { proxy.scrollTo("workshop.grid", anchor: .top) }
            }
            Divider()
            paginationBar
        }
    }

    private var paginationBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button("Previous", systemImage: "chevron.left") { workshop.previousPage() }
                    .disabled(!workshop.canGoPrevious)
                    .accessibilityIdentifier("workshop.previousPage")
                Spacer(minLength: 0)
                Group {
                    if let count = workshop.pagination.pageCount {
                        Text("Page \(workshop.currentPage) of \(count.formatted())")
                    } else {
                        Text("Page \(workshop.currentPage)")
                    }
                }
                .font(.callout).monospacedDigit()
                .accessibilityIdentifier("workshop.pageNumber")
                Spacer(minLength: 0)
                Button("Next", systemImage: "chevron.right") { workshop.nextPage() }
                    .disabled(!workshop.canGoNext)
                    .accessibilityIdentifier("workshop.nextPage")
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            if !workshop.items.isEmpty {
                if let total = workshop.total {
                    Text("\(workshop.pagination.firstResult.formatted())–\(workshop.pagination.lastResult.formatted()) of \(total.formatted()) wallpapers")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("\(workshop.items.count) wallpapers on this page")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.bar)
    }

    private func search() {
        previewItem = nil
        workshop.search()
    }
}
