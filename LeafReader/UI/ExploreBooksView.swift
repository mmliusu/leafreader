import SwiftUI

/// 某个书源下某个分类的书单
struct ExploreBooksView: View {
    let source: BookSource
    let category: ExploreCategory

    @EnvironmentObject private var library: LibraryStore

    @State private var books: [SourceSearchResult] = []
    @State private var loading = false
    @State private var page = 1
    @State private var finished = false
    @State private var selected: SourceSearchResult?
    @State private var toast: String?

    var body: some View {
        List {
            if loading && books.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }

            if !loading && books.isEmpty {
                Text("这个分类没有解析到书籍，可能书源规则不兼容或分类地址失效。")
                    .font(AppFont.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(books) { item in
                row(item)
                    .onTapGesture { selected = item }
            }

            if !books.isEmpty && !finished {
                Button {
                    loadNext()
                } label: {
                    HStack {
                        Spacer()
                        if loading {
                            ProgressView()
                        } else {
                            Text("加载更多")
                                .font(AppFont.footnote)
                        }
                        Spacer()
                    }
                }
                .disabled(loading)
            }
        }
        .listStyle(.plain)
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if books.isEmpty { await load(reset: true) }
        }
        .sheet(item: $selected) { item in
            BookDetailView(result: item)
                .environmentObject(library)
        }
        .alert("书架", isPresented: Binding(
            get: { toast != nil },
            set: { if !$0 { toast = nil } }
        )) {
            Button("好", role: .cancel) { toast = nil }
        } message: {
            Text(toast ?? "")
        }
    }

    private func row(_ item: SourceSearchResult) -> some View {
        HStack(spacing: 12) {
            cover(item)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(AppFont.body)
                    .lineLimit(1)
                Text(subtitle(item))
                    .font(AppFont.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let last = item.lastChapter, !last.isEmpty {
                    Text(last)
                        .font(AppFont.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .opacity(0.7)
                }
            }
            Spacer(minLength: 4)
            Button {
                addToShelf(item)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(hex: "#2E626B"))
            }
            .buttonStyle(.borderless)
        }
        .contentShape(Rectangle())
    }

    private func subtitle(_ item: SourceSearchResult) -> String {
        var parts: [String] = []
        if !item.author.isEmpty { parts.append(item.author) }
        if let kind = item.kind, !kind.isEmpty { parts.append(kind) }
        return parts.isEmpty ? source.displayName : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func cover(_ item: SourceSearchResult) -> some View {
        if let url = item.coverUrl.flatMap({ URL(string: $0) }) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    coverPlaceholder
                }
            }
            .frame(width: 46, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            coverPlaceholder
                .frame(width: 46, height: 64)
        }
    }

    private var coverPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color(uiColor: .secondarySystemFill))
            .overlay(
                Image(systemName: "book.closed")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(.secondary)
            )
    }

    private func addToShelf(_ item: SourceSearchResult) {
        let detail = SourceBookDetail(
            source: source,
            name: item.name,
            author: item.author,
            coverUrl: item.coverUrl,
            intro: item.intro,
            kind: item.kind,
            lastChapter: item.lastChapter,
            bookUrl: item.bookUrl,
            tocUrl: item.bookUrl,
            chapters: []
        )
        _ = library.addNetworkBook(detail: detail)
        toast = "已加入书架：《\(item.name)》，打开时自动获取目录"
    }

    private func loadNext() {
        guard !loading, !finished else { return }
        page += 1
        Task { await load(reset: false) }
    }

    private func load(reset: Bool) async {
        guard !loading else { return }
        loading = true
        if reset {
            page = 1
            finished = false
        }
        let currentPage = page
        let items = await BookSourceEngine.exploreBooks(source: source, category: category, page: currentPage)
        await MainActor.run {
            if reset {
                books = items
            } else {
                let existing = Set(books.map { $0.id })
                books.append(contentsOf: items.filter { !existing.contains($0.id) })
            }
            loading = false
            if items.isEmpty { finished = true }
        }
    }
}