import SwiftUI

struct SourceSearchView: View {
    var restrictSourceID: String? = nil

    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var keyword: String
    @State private var results: [SourceSearchResult] = []
    @State private var outcomes: [SourceSearchOutcome] = []
    @State private var searching = false
    @State private var finished = 0
    @State private var total = 0
    @State private var searched = false
    @State private var selected: SourceSearchResult?
    @State private var toast: String?

    init(restrictSourceID: String? = nil, initialKeyword: String = "") {
        self.restrictSourceID = restrictSourceID
        _keyword = State(initialValue: initialKeyword)
    }

    private var sources: [BookSource] {
        let all = BookSourceStore.shared.enabledSources
        if let restrict = restrictSourceID {
            return all.filter { $0.bookSourceUrl == restrict }
        }
        return all
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

                if searched && !searching && results.isEmpty {
                    Section("没有结果（共 \(total) 个书源）") {
                        if outcomes.isEmpty {
                            Text("没有可用的书源")
                                .font(AppFont.footnote)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(outcomes.indices, id: \.self) { index in
                            let outcome = outcomes[index]
                            HStack(spacing: 8) {
                                Text(outcome.sourceName)
                                    .font(AppFont.caption2)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(outcome.errorText ?? "无匹配")
                                    .font(AppFont.caption2)
                                    .foregroundStyle(outcome.errorText == nil ? Color.secondary : Color.red)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                }

                if !results.isEmpty {
                    Section("\(results.count) 个结果") {
                        ForEach(results) { item in
                            row(item)
                                .onTapGesture { selected = item }
                        }
                    }
                }

                if !searched && !searching {
                    Section {
                        Text(emptyHint)
                            .font(AppFont.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $keyword, prompt: "书名 / 作者")
            .onSubmit(of: .search) { startSearch() }
            .navigationTitle(restrictSourceID == nil ? "搜书" : "搜索书源")
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
                    .disabled(keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || searching)
                }
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
    }

    private var emptyHint: String {
        if sources.isEmpty {
            return "还没有启用任何支持搜索的书源。到「书源」Tab 导入书源 JSON 并确认开关已打开。"
        }
        return "输入书名或作者后按搜索，会并发检索 \(sources.count) 个已启用的书源。"
    }

    // MARK: - 行

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
            .accessibilityLabel("加入书架")
        }
        .contentShape(Rectangle())
    }

    private func subtitle(_ item: SourceSearchResult) -> String {
        var parts: [String] = []
        if !item.author.isEmpty { parts.append(item.author) }
        if let kind = item.kind, !kind.isEmpty { parts.append(kind) }
        parts.append(item.sourceName)
        return parts.joined(separator: " · ")
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

    // MARK: - 动作

    private func addToShelf(_ item: SourceSearchResult) {
        guard let source = BookSourceStore.shared.source(id: item.sourceID) else {
            toast = "书源已被删除，无法加入书架"
            return
        }
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
        toast = "已加入书架：《\(item.name)》。打开时会自动获取目录。"
    }

    private func startSearch() {
        let text = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let list = sources
        guard !list.isEmpty else {
            toast = "没有可用的书源"
            return
        }

        results = []
        outcomes = []
        searching = true
        searched = false
        finished = 0
        total = list.count

        Task {
            var collected: [SourceSearchResult] = []
            var tried: [SourceSearchOutcome] = []
            var index = 0
            let batchSize = 4

            while index < list.count {
                let end = min(index + batchSize, list.count)
                let batch = Array(list[index..<end])
                await withTaskGroup(of: SourceSearchOutcome.self) { group in
                    for source in batch {
                        group.addTask {
                            await BookSourceEngine.searchDetailed(source: source, keyword: text)
                        }
                    }
                    for await outcome in group {
                        tried.append(outcome)
                        collected.append(contentsOf: outcome.results)
                    }
                }
                index = end
                await MainActor.run {
                    results = dedupe(collected)
                    outcomes = tried
                    finished = index
                }
            }
            await MainActor.run {
                searching = false
                searched = true
            }
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