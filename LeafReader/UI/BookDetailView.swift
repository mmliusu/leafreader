import SwiftUI

struct BookDetailView: View {
    let result: SourceSearchResult

    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var detail: SourceBookDetail?
    @State private var loading = true
    @State private var errorText: String?
    @State private var downloading = false
    @State private var downloaded = 0
    @State private var toast: String?
    @State private var openBook: Book?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if loading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.top, 24)
                    } else if let errorText = errorText {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(errorText)
                                .font(AppFont.footnote)
                                .foregroundStyle(.secondary)
                            Button("重试") {
                                Task { await loadDetail() }
                            }
                            .buttonStyle(.bordered)
                        }
                    } else if let detail = detail {
                        introSection(detail)
                        actionSection(detail)
                        chapterSection(detail)
                    }
                }
                .padding(16)
            }
            .navigationTitle("书籍详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await loadDetail() }
            .fullScreenCover(item: $openBook) { book in
                ReaderView(book: book)
                    .environmentObject(library)
            }
            .alert("提示", isPresented: Binding(
                get: { toast != nil },
                set: { if !$0 { toast = nil } }
            )) {
                Button("好", role: .cancel) { toast = nil }
            } message: {
                Text(toast ?? "")
            }
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            cover
            VStack(alignment: .leading, spacing: 6) {
                Text(detail?.name ?? result.name)
                    .font(AppFont.headline)
                    .lineLimit(3)
                Text(metaLine)
                    .font(AppFont.footnote)
                    .foregroundStyle(.secondary)
                if let kind = (detail?.kind ?? result.kind), !kind.isEmpty {
                    Text(kind)
                        .font(AppFont.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text("来源：\(result.sourceName)")
                    .font(AppFont.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var coverURL: URL? {
        let raw = detail?.coverUrl ?? result.coverUrl
        guard let value = raw, !value.isEmpty else { return nil }
        return URL(string: value)
    }

    private var cover: some View {
        Group {
            if let url = coverURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        coverPlaceholder
                    }
                }
            } else {
                coverPlaceholder
            }
        }
        .frame(width: 96, height: 134)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private var coverPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(uiColor: .secondarySystemFill))
            .overlay(
                Image(systemName: "book.closed")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.secondary)
            )
    }

    private var metaLine: String {
        var parts: [String] = []
        let author = detail?.author ?? result.author
        if !author.isEmpty { parts.append(author) }
        if let count = detail?.chapters.count, count > 0 {
            parts.append("\(count) 章")
        }
        return parts.isEmpty ? "作者未知" : parts.joined(separator: " · ")
    }

    // MARK: - 简介 / 操作 / 目录

    private func introSection(_ detail: SourceBookDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("简介")
                .font(AppFont.headline)
            Text(introText(detail))
                .font(AppFont.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func introText(_ detail: SourceBookDetail) -> String {
        let value = (detail.intro ?? result.intro ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "暂无简介" : value
    }

    private func actionSection(_ detail: SourceBookDetail) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    addAndOpen(detail)
                } label: {
                    Label(existingBook == nil ? "加入书架" : "开始阅读", systemImage: "book")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    downloadAll(detail)
                } label: {
                    Label(downloading ? "\(downloaded)/\(detail.chapters.count)" : "下载全本", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(downloading)
            }

            if downloading {
                ProgressView(value: Double(downloaded), total: Double(max(detail.chapters.count, 1)))
            }
        }
    }

    private func chapterSection(_ detail: SourceBookDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("目录")
                    .font(AppFont.headline)
                Spacer()
                Text("共 \(detail.chapters.count) 章")
                    .font(AppFont.caption2)
                    .foregroundStyle(.secondary)
            }
            ForEach(detail.chapters.prefix(30)) { chapter in
                HStack(spacing: 6) {
                    Text(chapter.title)
                        .font(AppFont.footnote)
                        .lineLimit(1)
                    if chapter.isVip {
                        Text("VIP")
                            .font(AppFont.caption2)
                            .foregroundStyle(.orange)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 2)
            }
            if detail.chapters.count > 30 {
                Text("…… 其余 \(detail.chapters.count - 30) 章已省略")
                    .font(AppFont.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var existingBook: Book? {
        library.books.first { book in
            book.sourceID == result.sourceID && book.bookUrl == result.bookUrl
        }
    }

    // MARK: - 动作

    private func loadDetail() async {
        guard let source = BookSourceStore.shared.source(id: result.sourceID) else {
            await MainActor.run {
                errorText = "书源已被删除"
                loading = false
            }
            return
        }
        await MainActor.run {
            loading = true
            errorText = nil
        }
        do {
            let value = try await BookSourceEngine.detail(
                source: source,
                bookUrl: result.bookUrl,
                keyword: result.name,
                fallback: result
            )
            await MainActor.run {
                detail = value
                loading = false
            }
        } catch {
            await MainActor.run {
                errorText = error.localizedDescription
                loading = false
            }
        }
    }

    private func addAndOpen(_ detail: SourceBookDetail) {
        let book = library.addNetworkBook(detail: detail)
        openBook = book
    }

    private func downloadAll(_ detail: SourceBookDetail) {
        let book = library.addNetworkBook(detail: detail)
        let bookID = book.id
        let source = detail.source
        let chapters = detail.chapters

        downloading = true
        downloaded = 0
        var cached = 0
        for chapter in chapters where ChapterCache.isCached(bookID: bookID, index: chapter.id) {
            cached += 1
        }
        downloaded = cached

        Task {
            var index = 0
            let batchSize = 3
            while index < chapters.count {
                let end = min(index + batchSize, chapters.count)
                let batch = Array(chapters[index..<end])
                await withTaskGroup(of: Void.self) { group in
                    for chapter in batch {
                        group.addTask {
                            if ChapterCache.isCached(bookID: bookID, index: chapter.id) { return }
                            guard let content = try? await BookSourceEngine.content(
                                source: source,
                                chapterURL: chapter.url,
                                title: chapter.title
                            ) else { return }
                            let html = BookSourceEngine.chapterHTML(title: chapter.title, content: content)
                            ChapterCache.save(html: html, bookID: bookID, index: chapter.id)
                        }
                    }
                }
                index = end
                await MainActor.run { downloaded = index }
            }
            await MainActor.run {
                downloading = false
                toast = "已缓存 \(chapters.count) 章，可离线阅读"
            }
        }
    }
}