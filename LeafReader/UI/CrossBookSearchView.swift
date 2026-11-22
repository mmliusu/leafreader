import SwiftUI

struct CrossBookHit: Identifiable {
    var bookID: UUID
    var bookTitle: String
    var chapterIndex: Int
    var chapterTitle: String
    var snippet: String

    var id: String { "\(bookID.uuidString)|\(chapterIndex)|\(snippet)" }
}

struct CrossBookSearchView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var keyword = ""
    @State private var hits: [CrossBookHit] = []
    @State private var searching = false
    @State private var finished = false
    @State private var scanned = 0
    @State private var total = 0
    @State private var openedBook: Book?
    @State private var openedChapter = 0

    var body: some View {
        NavigationStack {
            List {
                if searching {
                    Section {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("正在搜索 \(scanned)/\(total) 本书…")
                                .font(AppFont.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if finished && hits.isEmpty && !searching {
                    Section {
                        Text("所有书里都没有找到「\(keyword)」")
                            .font(AppFont.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !hits.isEmpty {
                    Section("\(hits.count) 处匹配") {
                        ForEach(hits) { hit in
                            Button {
                                open(hit)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(hit.bookTitle)
                                        .font(AppFont.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Text(hit.chapterTitle)
                                        .font(AppFont.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Text(hit.snippet)
                                        .font(AppFont.footnote)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !searching && !finished {
                    Section {
                        Text("在书架所有书里搜索关键词（网络书只搜已下载章节）。结果按书分组，点开直接跳到该章。")
                            .font(AppFont.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $keyword, prompt: "在所有书中搜索")
            .onSubmit(of: .search) { run() }
            .navigationTitle("全书检索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        run()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .disabled(keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || searching)
                }
            }
            .fullScreenCover(item: $openedBook) { book in
                ReaderView(book: book, initialChapter: openedChapter)
                    .environmentObject(library)
            }
        }
    }

    private func open(_ hit: CrossBookHit) {
        guard let book = library.books.first(where: { $0.id == hit.bookID }) else { return }
        openedChapter = hit.chapterIndex
        openedBook = book
    }

    private func run() {
        let term = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty, !searching else { return }
        let books = library.books
        guard !books.isEmpty else { return }

        hits = []
        searching = true
        finished = false
        scanned = 0
        total = books.count

        Task {
            var collected: [CrossBookHit] = []
            for (offset, book) in books.enumerated() {
                if collected.count >= 120 { break }
                let fileURL = LibraryStore.shared.fileURL(for: book)
                let workDirectory = LibraryStore.shared.directory(for: book)
                let root = LibraryStore.shared.rootURL
                let found = await Task.detached(priority: .userInitiated) { () -> [BookSearchHit] in
                    guard let document = try? BookLoader.load(
                        book: book,
                        fileURL: fileURL,
                        workDirectory: workDirectory,
                        readAccessRoot: root
                    ) else { return [] }
                    return await BookSearchService.search(keyword: term, sections: document.sections, limit: 20)
                }.value

                collected.append(contentsOf: found.map {
                    CrossBookHit(
                        bookID: book.id,
                        bookTitle: book.title,
                        chapterIndex: $0.chapterIndex,
                        chapterTitle: $0.chapterTitle,
                        snippet: $0.snippet
                    )
                })

                await MainActor.run {
                    hits = collected
                    scanned = offset + 1
                }
            }
            await MainActor.run {
                searching = false
                finished = true
            }
        }
    }
}