import SwiftUI

struct SourceSearchView: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var keyword = ""
    @State private var results: [SourceSearchResult] = []
    @State private var searching = false
    @State private var finished = 0
    @State private var total = 0
    @State private var selected: SourceSearchResult?

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

                if results.isEmpty {
                    Section {
                        Text(emptyHint)
                            .font(AppFont.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        ForEach(results) { item in
                            Button {
                                selected = item
                            } label: {
                                row(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $keyword, prompt: "书名 / 作者")
            .onSubmit(of: .search) { startSearch() }
            .navigationTitle("搜书")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        startSearch()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .disabled(keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(item: $selected) { item in
                BookDetailView(result: item)
                    .environmentObject(library)
            }
        }
    }

    private var emptyHint: String {
        if BookSourceStore.shared.enabledSources.isEmpty {
            return "还没有启用书源。先在书架右上角进入「书源管理」导入 JSON。"
        }
        return "输入书名或作者后按搜索，会并发检索所有已启用的书源。"
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
            Text(item.sourceName)
                .font(AppFont.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: 72, alignment: .trailing)
        }
        .contentShape(Rectangle())
    }

    private func subtitle(_ item: SourceSearchResult) -> String {
        var parts: [String] = []
        if !item.author.isEmpty { parts.append(item.author) }
        if let kind = item.kind, !kind.isEmpty { parts.append(kind) }
        return parts.isEmpty ? item.sourceName : parts.joined(separator: " · ")
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

    private func startSearch() {
        let text = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let sources = BookSourceStore.shared.enabledSources
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