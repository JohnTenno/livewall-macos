import SwiftUI

/// Browses the Wallpaper Engine Workshop and downloads video/web items into the library.
struct WorkshopView: View {
    /// Sends the user to Settings, where the Steam API key and sign-in live.
    let openSettings: () -> Void

    @EnvironmentObject private var workshop: WorkshopModel
    @EnvironmentObject private var account: SteamAccount
    @EnvironmentObject private var library: WallpaperLibrary

    @State private var previewItem: WorkshopItem?
    @State private var showsPreview = true
    @State private var showsFilters = false

    private let columns = [GridItem(.adaptive(minimum: 180, maximum: 260), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            if let error = workshop.error {
                ErrorBanner(message: error)
            }

            if workshop.needsLogin {
                HStack {
                    Text("Downloading needs your Steam account. Sign in by scanning a QR code, then press Download again.")
                        .font(.callout)
                    Spacer()
                    Button("Sign in with Steam…") { account.signIn() }
                }
                .padding(10)
            }

            HSplitView {
                Group {
                    if account.trimmedAPIKey.isEmpty {
                        ContentUnavailableView {
                            Label("Add a Steam API key to search", systemImage: "key")
                        } description: {
                            Text("Searching the Workshop needs a free Steam Web API key. Downloading is a separate step: signing in with the Steam app.")
                        } actions: {
                            Button("Open Steam settings") { openSettings() }
                        }
                    } else if workshop.items.isEmpty && !workshop.isLoading {
                        ContentUnavailableView("Search wallpapers", systemImage: "magnifyingglass",
                                               description: Text("Only video and web wallpapers are shown, the ones Livewall can play."))
                    } else {
                        results
                    }
                }
                .frame(minWidth: 300, maxWidth: .infinity, maxHeight: .infinity)

                if showsPreview {
                    // One stable split-view pane: swapping the pane itself on every selection rebuilt the grid and lost its scroll.
                    ZStack {
                        if let item = previewItem {
                            WorkshopInspector(item: item, onClose: { showsPreview = false })
                                .id(item.id)
                        } else {
                            VStack(spacing: 0) {
                                InspectorHeader(title: "Workshop preview", onClose: { showsPreview = false })
                                ContentUnavailableView("Select a wallpaper", systemImage: "play.rectangle",
                                    description: Text("Choose a card to see its preview and details."))
                                    .frame(maxHeight: .infinity)
                            }
                            .background(.background.secondary)
                        }
                    }
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
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
            Picker("Sort", selection: $workshop.query.sort) {
                ForEach(WorkshopSort.allCases) { Text($0.displayName).tag($0) }
            }
            .fixedSize()
            if workshop.query.sort == .trending && workshop.query.text.trimmingCharacters(in: .whitespaces).isEmpty {
                Picker("Period", selection: $workshop.query.period) {
                    ForEach(WorkshopPeriod.allCases) { Text($0.displayName).tag($0) }
                }
                .fixedSize()
            }
            Button {
                showsFilters.toggle()
            } label: {
                let count = workshop.query.filters.activeCount
                Label(count == 0 ? "Filters" : "Filters (\(count))", systemImage: "line.3.horizontal.decrease.circle")
            }
            .labelStyle(.titleAndIcon)
            .popover(isPresented: $showsFilters, arrowEdge: .bottom) {
                WorkshopFiltersView(filters: $workshop.query.filters)
            }
            Button("Search", systemImage: "magnifyingglass") { search() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.glassProminent)
        }
        .labelsHidden()
        .padding(10)
        .glassEffect(in: .rect(cornerRadius: 16))
        .padding([.horizontal, .top], 10)
        .onChange(of: workshop.query.sort) { search() }
        .onChange(of: workshop.query.period) { search() }
        .onChange(of: workshop.query.filters) { search() }
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
