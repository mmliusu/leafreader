import SwiftUI

/// 换源：用当前书名在其它书源里搜索，选中后替换书籍来源。
struct SourceSwitchView: View {
    let bookTitle: String
    let excludeSourceID: String
    let onPick: (SourceSearchResult) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var keyword: String
    @State private var results: [SourceSearchResult] = []
    @State private var searching = false
    @State private var finished = 0
    @State private var total = 0

    init(bookTitle: String, excludeSourceID: String, onPick: @escaping (SourceSearchResult) -> Void) {
        self.bookTitle = bookTitle
        self.excludeSourceID = excludeSourceID
        self.onPick = onPick
        _keyword = State(initialValue: bookTitle)
    }

    var body: some View {
        NavigationStack {
            List {
                if searching {
                    Section {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("正在搜索 \(finished)/\(total) 个书源…")
                                .font(AppFont.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if results.isEmpty && !searching {
                    Section {
                        Text("在其它书源里搜索同名书，选中后会保留书名并重新抓取目录。")
                            .font(AppFont.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(results) { item in
                            Button {
                                onPick(item)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(AppFont.body)
                                        .lineLimit(1)
                                    Text("\(item.sourceName) · \(item.author)")
                                        .font(AppFont.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $keyword, prompt: "书名")
            .onSubmit(of: .search) { start() }
            .navigationTitle("换源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        start()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .onAppear {
                if results.isEmpty && !searching {
                    start()
                }
            }
        }
    }

    private func start() {
        let text = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let sources = BookSourceStore.shared.enabledSources.filter { $0.bookSourceUrl != excludeSourceID }
        guard !sources.isEmpty else { return }

        results = []
        searching = true
        finished = 0
        total = sources.count

        Task {
            var collected: [SourceSearchResult] = []
            var index = 0
            let batchSize = 4
            while index < sources.count {
                let end = min(index + batchSize, sources.count)
                let batch = Array(sources[index..<end])
                await withTaskGroup(of: [SourceSearchResult].self) { group in
                    for source in batch {
                        group.addTask {
                            await BookSourceEngine.search(source: source, keyword: text)
                        }
                    }
                    for await items in group {
                        collected.append(contentsOf: items)
                    }
                }
                index = end
                await MainActor.run {
                    results = dedupe(collected)
                    finished = index
                }
            }
            await MainActor.run { searching = false }
        }
    }

    private func dedupe(_ items: [SourceSearchResult]) -> [SourceSearchResult] {
        var seen = Set<String>()
        var output: [SourceSearchResult] = []
        for item in items where !seen.contains(item.id) {
            seen.insert(item.id)
            output.append(item)
        }
        return output
    }
}