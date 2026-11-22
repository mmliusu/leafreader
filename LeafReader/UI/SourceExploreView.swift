import SwiftUI

struct SourceExploreView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSourceID: String = ""
    @State private var categories: [ExploreCategory] = []
    @State private var books: [SourceSearchResult] = []
    @State private var loading = false
    @State private var selectedBook: SourceSearchResult?
    @State private var message: String?

    private var exploreSources: [BookSource] {
        BookSourceStore.shared.sources.filter { !($0.exploreUrl ?? "").isEmpty && $0.isEnabled }
    }

    private var currentSource: BookSource? {
        BookSourceStore.shared.source(id: selectedSourceID)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("书源") {
                    Picker("书源", selection: $selectedSourceID) {
                        ForEach(exploreSources) { source in
                            Text(source.displayName).tag(source.bookSourceUrl)
                        }
                    }
                    .onChange(of: selectedSourceID) { _ in
                        books = []
                        loadCategories()
                    }
                }

                if loading {
                    Section {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("加载中…")
                                .font(AppFont.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !categories.isEmpty {
                    Section("分类") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 8)], spacing: 8) {
                            ForEach(categories) { category in
                                Button {
                                    loadBooks(category)
                                } label: {
                                    Text(category.title)
                                        .font(AppFont.footnote)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 7)
                                        .background(Color(uiColor: .secondarySystemFill))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if !books.isEmpty {
                    Section("书籍") {
                        ForEach(books) { item in
                            Button {
                                selectedBook = item
                            } label: {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(AppFont.body)
                                            .lineLimit(1)
                                        Text(item.author.isEmpty ? item.sourceName : item.author)
                                            .font(AppFont.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if exploreSources.isEmpty {
                    Section {
                        Text("当前没有支持「发现」的书源。只有带 exploreUrl 的书源才会出现在这里。")
                            .font(AppFont.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("发现")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear {
                if selectedSourceID.isEmpty, let first = exploreSources.first {
                    selectedSourceID = first.bookSourceUrl
                    loadCategories()
                }
            }
            .sheet(item: $selectedBook) { item in
                BookDetailView(result: item)
                    .environmentObject(library)
            }
            .alert("发现", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("知道了", role: .cancel) { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
    }

    private func loadCategories() {
        guard let source = currentSource else {
            categories = []
            return
        }
        categories = BookSourceEngine.categories(for: source)
        if categories.isEmpty {
            message = "这个书源没有可用的发现分类"
        }
    }

    private func loadBooks(_ category: ExploreCategory) {
        guard let source = currentSource else { return }
        loading = true
        books = []
        Task {
            let items = await BookSourceEngine.exploreBooks(source: source, category: category, page: 1)
            await MainActor.run {
                books = items
                loading = false
                if items.isEmpty {
                    message = "这个分类没有解析到书籍，可能规则不兼容"
                }
            }
        }
    }
}