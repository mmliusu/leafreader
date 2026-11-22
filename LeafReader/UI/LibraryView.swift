import SwiftUI
import UIKit

enum LibrarySort: String, CaseIterable, Identifiable {
    case recent
    case added
    case title
    case author
    case progress
    case duration

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: return "最近阅读"
        case .added: return "最近添加"
        case .title: return "书名"
        case .author: return "作者"
        case .progress: return "阅读进度"
        case .duration: return "阅读时长"
        }
    }
}

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var settings: ReadingSettings

    @State private var showImporter = false
    @State private var showSearch = false
    @State private var showSources = false
    @State private var showExplore = false
    @State private var showCrossSearch = false
    @State private var showStats = false
    @State private var query = ""
    @AppStorage("library.sort") private var sortRaw = LibrarySort.recent.rawValue
    @State private var openedBook: Book?
    @State private var pendingDelete: Book?
    @State private var showError = false

    private let columns = [
        GridItem(.adaptive(minimum: 104, maximum: 150), spacing: 18, alignment: .top)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if library.books.isEmpty {
                    emptyState
                } else {
                    bookGrid
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("书架")
            .searchable(text: $query, prompt: "搜索书名或作者")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("排序", selection: $sortRaw) {
                            ForEach(LibrarySort.allCases) { option in
                                Text(option.title).tag(option.rawValue)
                            }
                        }
                        Divider()
                        Button {
                            showCrossSearch = true
                        } label: {
                            Label("全文搜索", systemImage: "text.magnifyingglass")
                        }
                        Button {
                            showStats = true
                        } label: {
                            Label("阅读统计", systemImage: "chart.bar")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showSearch = true
                        } label: {
                            Label("搜书", systemImage: "magnifyingglass")
                        }
                        Button {
                            showExplore = true
                        } label: {
                            Label("发现", systemImage: "safari")
                        }
                        Button {
                            showSources = true
                        } label: {
                            Label("书源管理", systemImage: "server.rack")
                        }
                        Button {
                            showImporter = true
                        } label: {
                            Label("导入本地文件", systemImage: "doc.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("添加")
                }
            }
        }
        .sheet(isPresented: $showSearch) {
            SourceSearchView()
                .environmentObject(library)
        }
        .sheet(isPresented: $showCrossSearch) {
            CrossBookSearchView()
                .environmentObject(library)
        }
        .sheet(isPresented: $showStats) {
            StatsView()
                .environmentObject(library)
        }
        .sheet(isPresented: $showExplore) {
            SourceExploreView()
                .environmentObject(library)
        }
        .sheet(isPresented: $showSources) {
            SourceListView()
                .environmentObject(BookSourceStore.shared)
                .environmentObject(library)
        }
        .sheet(isPresented: $showImporter) {
            DocumentPickerView(isPresented: $showImporter) { urls in
                for url in urls {
                    _ = library.importBook(from: url)
                }
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
                if let book = pendingDelete {
                    library.delete(book)
                }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text("书文件会从设备上移除，此操作不可恢复。")
        }
        .alert("导入失败", isPresented: $showError) {
            Button("知道了", role: .cancel) {
                library.lastError = nil
            }
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

    private var displayedBooks: [Book] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        let filtered = trimmed.isEmpty
            ? library.books
            : library.books.filter {
                $0.title.localizedCaseInsensitiveContains(trimmed)
                    || $0.author.localizedCaseInsensitiveContains(trimmed)
            }

        switch LibrarySort(rawValue: sortRaw) ?? .recent {
        case .recent:
            return filtered.sorted { ($0.lastOpenedAt ?? $0.addedAt) > ($1.lastOpenedAt ?? $1.addedAt) }
        case .added:
            return filtered.sorted { $0.addedAt > $1.addedAt }
        case .title:
            return filtered.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .author:
            return filtered.sorted { $0.author.localizedStandardCompare($1.author) == .orderedAscending }
        case .progress:
            return filtered.sorted { $0.progress > $1.progress }
        case .duration:
            return filtered.sorted {
                StatsStore.shared.seconds(for: $0.id) > StatsStore.shared.seconds(for: $1.id)
            }
        }
    }

    private var bookGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 22) {
                ForEach(displayedBooks) { book in
                    BookCard(book: book)
                        .onTapGesture {
                            openedBook = book
                        }
                        .contextMenu {
                            Button {
                                pendingDelete = book
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                            Button {
                                library.resetProgress(book)
                            } label: {
                                Label("标记为未读", systemImage: "arrow.counterclockwise")
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "books.vertical")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(.secondary)
            Text("书架还是空的")
                .font(AppFont.headline)
            Text("导入 TXT、EPUB 或 PDF 开始阅读")
                .font(AppFont.footnote)
                .foregroundStyle(.secondary)
            Button {
                showImporter = true
            } label: {
                Label("导入书籍", systemImage: "plus")
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}