import SwiftUI

struct ShelfGroup: Identifiable {
    var title: String
    var books: [Book]

    var id: String { title }
}

/// 书架主页：极简入口 + 深藏配置。
/// 顶栏四个控件（筛选 / 搜索 / 闪电快捷键 / 三点菜单），
/// 高级设置收进三点菜单的分组里，复杂配置用底部弹层。
struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var settings: ReadingSettings
    @EnvironmentObject private var sourceStore: BookSourceStore

    @Environment(\.colorScheme) private var scheme

    @AppStorage("shelf.view") private var viewRaw = ShelfViewMode.grid.rawValue
    @AppStorage("shelf.filter") private var filterRaw = ShelfFilter.all.rawValue
    @AppStorage("shelf.sort") private var sortRaw = ShelfSortKey.recent.rawValue
    @AppStorage("shelf.desc") private var descendingSort = true
    @AppStorage("shelf.categoryFirst") private var categoryFirst = true
    @AppStorage("shelf.showCategory") private var showCategory = true
    @AppStorage("shelf.top") private var topRaw = ShelfTopStyle.off.rawValue
    @AppStorage("shelf.quick") private var quickRaw = ShelfQuickAction.toggleTheme.rawValue
    @AppStorage("ui.appearance") private var appearance = "system"
    // 读取字号设置，让「我的 → 外观」调字号时书架跟着刷新（不再重建视图树）
    @AppStorage(AppFont.baseKey) private var uiBase = 16.0
    @AppStorage(AppFont.fontKey) private var uiFont = UIFontChoice.jinling.rawValue

    @State private var showImporter = false
    @State private var showSourceSearch = false
    @State private var showCrossSearch = false
    @State private var showSearchPage = false
    @State private var showSortSheet = false
    @State private var showToolbox = false
    @State private var showTopSettings = false
    @State private var showAppearance = false
    @State private var openedBook: Book?
    @State private var pendingDelete: Book?
    @State private var showError = false

    private var viewMode: ShelfViewMode { ShelfViewMode(rawValue: viewRaw) ?? .grid }
    private var filter: ShelfFilter { ShelfFilter(rawValue: filterRaw) ?? .all }
    private var topStyle: ShelfTopStyle { ShelfTopStyle(rawValue: topRaw) ?? .off }
    private var quickAction: ShelfQuickAction { ShelfQuickAction(rawValue: quickRaw) ?? .toggleTheme }

    private let columns = [
        GridItem(.adaptive(minimum: 104, maximum: 150), spacing: 16, alignment: .top)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                content
            }
            .background(ShelfStyle.background(scheme).ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showAppearance) {
                AppearanceView()
            }
        }
        .sheet(isPresented: $showSearchPage) {
            ShelfSearchPage(books: library.books) { book in
                openedBook = book
            }
            .environmentObject(library)
            .environmentObject(sourceStore)
        }
        .sheet(isPresented: $showSourceSearch) {
            SourceSearchView()
                .environmentObject(library)
        }
        .sheet(isPresented: $showCrossSearch) {
            CrossBookSearchView()
                .environmentObject(library)
        }
        .sheet(isPresented: $showImporter) {
            DocumentPickerView(isPresented: $showImporter) { urls in
                for url in urls {
                    _ = library.importBook(from: url)
                }
            }
        }
        .sheet(isPresented: $showSortSheet) {
            ShelfSortSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showToolbox) {
            ShelfToolboxSheet(
                onFullTextSearch: {
                    showToolbox = false
                    showCrossSearch = true
                },
                onRandomPreview: {
                    showToolbox = false
                    openedBook = library.books.randomElement()
                },
                onSourceSearch: {
                    showToolbox = false
                    showSourceSearch = true
                },
                onImport: {
                    showToolbox = false
                    showImporter = true
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTopSettings) {
            NavigationStack {
                ShelfTopSettingsView(topRaw: $topRaw)
            }
        }
        .fullScreenCover(item: $openedBook) { book in
            ReaderView(book: book)
                .environmentObject(library)
                .environmentObject(settings)
        }
        .confirmationDialog(
            "删除《\(pendingDelete?.title ?? "")》？",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let book = pendingDelete { library.delete(book) }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("书文件会从设备上移除，此操作不可恢复。")
        }
        .alert("导入失败", isPresented: $showError) {
            Button("知道了", role: .cancel) { library.lastError = nil }
        } message: {
            Text(library.lastError ?? "")
        }
        .onChange(of: library.lastError) { value in
            showError = (value != nil)
        }
        .onOpenURL { url in
            library.importIncomingFile(at: url)
        }
    }

    // MARK: - 顶栏

    private var header: some View {
        HStack(spacing: 14) {
            Text("书架")
                .font(AppFont.title.bold())
                .foregroundStyle(ShelfStyle.accent)

            Spacer(minLength: 0)

            filterMenu

            Button {
                showSearchPage = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(ShelfStyle.accent)
            }
            .accessibilityLabel("搜索书架")

            Button {
                runQuickAction()
            } label: {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(quickAction == .none ? ShelfStyle.secondaryText(scheme) : ShelfStyle.accent)
            }
            .accessibilityLabel("快速启动：\(quickAction.title)")

            moreMenu
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private var filterMenu: some View {
        Menu {
            ForEach(ShelfFilter.allCases) { option in
                Button {
                    filterRaw = option.rawValue
                } label: {
                    if option == filter {
                        Label(option.title, systemImage: "checkmark")
                    } else {
                        Text(option.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(filter.title)
                    .font(AppFont.callout)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(ShelfStyle.accent)
        }
    }

    private var moreMenu: some View {
        Menu {
            Section {
                Button {
                    showCategory.toggle()
                } label: {
                    if showCategory {
                        Label("书架上显示分类", systemImage: "checkmark")
                    } else {
                        Text("书架上显示分类")
                    }
                }
                ForEach(ShelfViewMode.allCases) { mode in
                    Button {
                        viewRaw = mode.rawValue
                    } label: {
                        if mode == viewMode {
                            Label(mode.title, systemImage: "checkmark")
                        } else {
                            Text(mode.title)
                        }
                    }
                }
            }

            Section {
                Button {
                    showTopSettings = true
                } label: {
                    Label("书架顶部展示", systemImage: "rectangle.grid.1x2")
                }
                Button {
                    showSortSheet = true
                } label: {
                    Label("书架排序", systemImage: "arrow.up.arrow.down")
                }
            }

            Section {
                Menu {
                    ForEach(ShelfQuickAction.allCases) { action in
                        Button {
                            quickRaw = action.rawValue
                        } label: {
                            if action == quickAction {
                                Label(action.title, systemImage: "checkmark")
                            } else {
                                Text(action.title)
                            }
                        }
                    }
                } label: {
                    Label("快速启动", systemImage: "bolt")
                }
                Button {
                    showToolbox = true
                } label: {
                    Label("工具箱", systemImage: "wrench.and.screwdriver")
                }
                Button {
                    showImporter = true
                } label: {
                    Label("导入本地文件", systemImage: "doc.badge.plus")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(ShelfStyle.accent)
        }
        .accessibilityLabel("更多设置")
    }

    private func runQuickAction() {
        switch quickAction {
        case .toggleTheme:
            appearance = scheme == .dark ? "light" : "dark"
        case .appearance:
            showAppearance = true
        case .none:
            break
        }
    }

    // MARK: - 内容

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !library.books.isEmpty, topStyle != .off {
                    ShelfTopSection(style: topStyle, books: library.books) { book in
                        openedBook = book
                    }
                    .padding(.horizontal, 16)
                }

                if library.books.isEmpty {
                    ShelfEmptyState(
                        onImport: { showImporter = true },
                        onSearchSource: { showSourceSearch = true }
                    )
                    .padding(.top, 40)
                } else if displayedBooks.isEmpty {
                    filteredEmpty
                } else if showCategory && categoryFirst {
                    groupedContent
                } else {
                    flatContent(displayedBooks)
                }
            }
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private func flatContent(_ books: [Book]) -> some View {
        switch viewMode {
        case .grid:
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(books) { book in
                    ShelfGridCell(book: book, category: category(for: book), showCategory: showCategory)
                        .onTapGesture { openedBook = book }
                        .contextMenu { contextMenu(for: book) }
                }
            }
            .padding(.horizontal, 16)
        case .list, .plain:
            LazyVStack(spacing: 0) {
                ForEach(books) { book in
                    ShelfListRow(
                        book: book,
                        category: category(for: book),
                        showCategory: showCategory,
                        showCover: viewMode == .list
                    )
                    .onTapGesture { openedBook = book }
                    .contextMenu { contextMenu(for: book) }
                    if book.id != books.last?.id {
                        Divider()
                            .background(ShelfStyle.separator(scheme))
                            .padding(.leading, viewMode == .list ? 56 : 0)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(ShelfStyle.card(scheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
        }
    }

    private var groupedContent: some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            ForEach(groupedBooks) { group in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Text(group.title)
                            .font(AppFont.headline)
                            .foregroundStyle(ShelfStyle.primaryText(scheme))
                        Text("\(group.books.count)")
                            .font(AppFont.caption2)
                            .foregroundStyle(ShelfStyle.secondaryText(scheme))
                    }
                    .padding(.horizontal, 16)
                    flatContent(group.books)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private var filteredEmpty: some View {
        VStack(spacing: 10) {
            Image(systemName: filter.symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(ShelfStyle.secondaryText(scheme))
            Text("「\(filter.title)」里还没有书")
                .font(AppFont.callout)
                .foregroundStyle(ShelfStyle.primaryText(scheme))
            Button("看全部") { filterRaw = ShelfFilter.all.rawValue }
                .font(AppFont.footnote)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - 数据

    private var displayedBooks: [Book] {
        let filtered = library.books.filter { filter.matches($0) }
        return sorted(filtered)
    }

    private func sorted(_ books: [Book]) -> [Book] {
        let key = ShelfSortKey(rawValue: sortRaw) ?? .recent
        let ascending = !descendingSort
        func order<T: Comparable>(_ lhs: T, _ rhs: T) -> Bool {
            ascending ? lhs < rhs : lhs > rhs
        }
        return books.sorted { a, b in
            switch key {
            case .recent:
                return order(a.lastOpenedAt ?? a.addedAt, b.lastOpenedAt ?? b.addedAt)
            case .added:
                return order(a.addedAt, b.addedAt)
            case .size:
                return order(a.fileSize, b.fileSize)
            case .title:
                let result = a.title.localizedStandardCompare(b.title)
                return ascending ? result == .orderedAscending : result == .orderedDescending
            case .progress:
                return order(a.progress, b.progress)
            case .duration:
                return order(StatsStore.shared.seconds(for: a.id), StatsStore.shared.seconds(for: b.id))
            }
        }
    }

    private var groupedBooks: [ShelfGroup] {
        var order: [String] = []
        var buckets: [String: [Book]] = [:]
        for book in displayedBooks {
            let title = category(for: book)
            if buckets[title] == nil { order.append(title) }
            buckets[title, default: []].append(book)
        }
        // 分类按数量从多到少，数量相同按名称
        order.sort { lhs, rhs in
            let left = buckets[lhs]?.count ?? 0
            let right = buckets[rhs]?.count ?? 0
            if left == right { return lhs.localizedStandardCompare(rhs) == .orderedAscending }
            return left > right
        }
        return order.map { ShelfGroup(title: $0, books: buckets[$0] ?? []) }
    }

    private func category(for book: Book) -> String {
        ShelfCategory.title(for: book, sources: sourceStore)
    }

    @ViewBuilder
    private func contextMenu(for book: Book) -> some View {
        Button {
            openedBook = book
        } label: {
            Label("打开", systemImage: "book")
        }
        Button {
            library.resetProgress(book)
        } label: {
            Label("标记为未读", systemImage: "arrow.counterclockwise")
        }
        Button(role: .destructive) {
            pendingDelete = book
        } label: {
            Label("删除", systemImage: "trash")
        }
    }
}