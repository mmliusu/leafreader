import SwiftUI

/// 书源 Tab：左侧书源列表，右侧该源的分类；点分类进书单，点书进详情。
struct SourceDiscoverTabView: View {
    @EnvironmentObject private var sourceStore: BookSourceStore
    @EnvironmentObject private var library: LibraryStore

    @AppStorage("discover.source") private var storedSourceID = ""

    @State private var selectedSourceID = ""
    @State private var query = ""
    @State private var categories: [ExploreCategory] = []
    @State private var showManage = false
    @State private var showGlobalSearch = false
    @State private var showSourceSearch = false
    @State private var browserTarget: BrowserTarget?

    private var enabledSources: [BookSource] {
        sourceStore.sources.filter { $0.isEnabled }
    }

    private var filteredSources: [BookSource] {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return enabledSources }
        return enabledSources.filter {
            $0.displayName.localizedCaseInsensitiveContains(text)
                || $0.host.localizedCaseInsensitiveContains(text)
        }
    }

    private var currentSource: BookSource? {
        enabledSources.first { $0.bookSourceUrl == selectedSourceID }
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                sidebar
                Divider()
                content
            }
            .navigationTitle("书源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showGlobalSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .disabled(enabledSources.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("管理") { showManage = true }
                }
            }
            .sheet(isPresented: $showManage) {
                SourceListView()
                    .environmentObject(sourceStore)
                    .environmentObject(library)
            }
            .sheet(isPresented: $showGlobalSearch) {
                SourceSearchView()
                    .environmentObject(library)
            }
            .sheet(isPresented: $showSourceSearch) {
                SourceSearchView(restrictSourceID: selectedSourceID)
                    .environmentObject(library)
            }
            .sheet(item: $browserTarget) { target in
                BrowserPreview(url: target.url, sourceName: target.name)
            }
            .onAppear(perform: restoreSelection)
            .onChange(of: sourceStore.sources) { _ in restoreSelection() }
        }
    }

    // MARK: - 左侧

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                TextField("查找书源", text: $query)
                    .font(AppFont.footnote)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(uiColor: .tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(8)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredSources) { source in
                        Button {
                            select(source)
                        } label: {
                            HStack(spacing: 4) {
                                Text(source.displayName)
                                    .font(AppFont.footnote)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                selectedSourceID == source.bookSourceUrl
                                    ? Color(hex: "#2E626B").opacity(0.14)
                                    : Color.clear
                            )
                            .overlay(alignment: .leading) {
                                if selectedSourceID == source.bookSourceUrl {
                                    Rectangle()
                                        .fill(Color(hex: "#2E626B"))
                                        .frame(width: 3)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 14)
            }
        }
        .frame(width: 148)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: - 右侧

    @ViewBuilder
    private var content: some View {
        if enabledSources.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "server.rack")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.secondary)
                Text("还没有启用的书源")
                    .font(AppFont.headline)
                Text("点右上角「管理」导入书源 JSON")
                    .font(AppFont.footnote)
                    .foregroundStyle(.secondary)
                Button("去导入") { showManage = true }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let source = currentSource {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    sourceHeader(source)

                    if categories.isEmpty {
                        emptyCategoryHint(source)
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 10
                        ) {
                            ForEach(categories) { category in
                                NavigationLink {
                                    ExploreBooksView(source: source, category: category)
                                        .environmentObject(library)
                                } label: {
                                    Text(category.title)
                                        .font(AppFont.footnote)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(14)
                .padding(.bottom, 14)
            }
        } else {
            Text("选择左侧的书源")
                .font(AppFont.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func sourceHeader(_ source: BookSource) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.displayName)
                    .font(AppFont.headline)
                    .lineLimit(1)
                Text(source.host)
                    .font(AppFont.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button {
                showSourceSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
            }
            .buttonStyle(.borderless)
            .disabled(!source.canSearch)

            Button {
                if let url = URL(string: source.bookSourceUrl) {
                    browserTarget = BrowserTarget(url: url, name: source.displayName)
                }
            } label: {
                Image(systemName: "safari")
                    .font(.system(size: 15))
            }
            .buttonStyle(.borderless)
        }
    }

    private func emptyCategoryHint(_ source: BookSource) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("这个书源没有配置「发现分类」")
                .font(AppFont.headline)
            Text("只支持直接搜索。点下面的按钮用书名搜这个源，或换左边的其它书源。")
                .font(AppFont.footnote)
                .foregroundStyle(.secondary)
            Button {
                showSourceSearch = true
            } label: {
                Label("搜索此书源", systemImage: "magnifyingglass")
            }
            .buttonStyle(.bordered)
            .disabled(!source.canSearch)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - 选择

    private func restoreSelection() {
        guard !enabledSources.isEmpty else {
            selectedSourceID = ""
            categories = []
            return
        }
        if !storedSourceID.isEmpty,
           enabledSources.contains(where: { $0.bookSourceUrl == storedSourceID }) {
            selectedSourceID = storedSourceID
        } else if selectedSourceID.isEmpty
            || !enabledSources.contains(where: { $0.bookSourceUrl == selectedSourceID }) {
            let first = enabledSources.first { !($0.exploreUrl ?? "").isEmpty } ?? enabledSources[0]
            selectedSourceID = first.bookSourceUrl
        }
        if let source = currentSource {
            categories = BookSourceEngine.categories(for: source)
        }
    }

    private func select(_ source: BookSource) {
        selectedSourceID = source.bookSourceUrl
        storedSourceID = source.bookSourceUrl
        categories = BookSourceEngine.categories(for: source)
    }
}

struct BrowserTarget: Identifiable {
    var id: String { url.absoluteString }
    var url: URL
    var name: String
}