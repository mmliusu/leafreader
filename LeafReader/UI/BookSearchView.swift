import SwiftUI

struct BookSearchView: View {
    let sections: [ReadingSection]
    let onSelect: (BookSearchHit, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var keyword = ""
    @State private var hits: [BookSearchHit] = []
    @State private var searching = false
    @State private var finished = false

    var body: some View {
        NavigationStack {
            List {
                if searching {
                    Section {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("正在搜索 \(sections.count) 个章节…")
                                .font(AppFont.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if finished && hits.isEmpty && !searching {
                    Section {
                        Text("没有找到「\(keyword)」")
                            .font(AppFont.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !hits.isEmpty {
                    Section("\(hits.count) 处匹配") {
                        ForEach(hits) { hit in
                            Button {
                                onSelect(hit, keyword)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
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

                if hits.isEmpty && !searching && !finished {
                    Section {
                        Text("输入关键词后搜索全书（网络书只搜已下载的章节）。")
                            .font(AppFont.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $keyword, prompt: "搜索全书")
            .onSubmit(of: .search) { run() }
            .navigationTitle("全文搜索")
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
                    .disabled(keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func run() {
        let term = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty, !searching else { return }
        searching = true
        finished = false
        hits = []

        Task {
            let result = await BookSearchService.search(keyword: term, sections: sections)
            await MainActor.run {
                hits = result
                searching = false
                finished = true
            }
        }
    }
}