import SwiftUI
import Combine

final class ReaderViewModel: ObservableObject {
    let book: Book

    @Published var document: ReadingDocument?
    @Published var sectionIndex: Int
    @Published var sectionProgress: Double
    @Published var pdfPageIndex: Int
    @Published var pdfPageCount: Int
    @Published var pageIndex: Int = 0
    @Published var pageCount: Int = 0
    @Published var isLoading = true
    @Published var isLoadingChapter = false
    @Published var chapterError: String?
    @Published var reloadToken = 0
    @Published var highlightTerm = ""
    @Published var highlightToken = 0

    private var loadingIndexes: Set<Int> = []
    private(set) var sessionPageTurns = 0
    @Published var errorMessage: String?

    private var lastPersist = Date.distantPast
    private var pendingSave: DispatchWorkItem?

    init(book: Book, initialChapter: Int? = nil) {
        self.book = book
        self.sectionIndex = max(0, initialChapter ?? book.locator.chapterIndex)
        self.sectionProgress = min(max(book.locator.chapterProgress, 0), 1)
        self.pdfPageIndex = max(0, book.locator.pageIndex)
        self.pdfPageCount = book.pageCount ?? 0
    }

    // MARK: - 派生状态

    var sectionCount: Int {
        document?.sections.count ?? 1
    }

    var overallProgress: Double {
        currentLocator.overall
    }

    var progressText: String {
        "\(Int((overallProgress * 100).rounded()))%"
    }

    var currentSection: ReadingSection? {
        document?.sections[safe: sectionIndex]
    }

    var currentLocator: ReadingLocator {
        if book.format == .pdf {
            let denominator = max(1, pdfPageCount - 1)
            let overall = pdfPageCount > 1 ? Double(pdfPageIndex) / Double(denominator) : 0
            return ReadingLocator(
                overall: min(1, max(0, overall)),
                chapterIndex: 0,
                chapterProgress: 0,
                pageIndex: pdfPageIndex
            )
        }
        let total = max(1, sectionCount)
        let overall = (Double(sectionIndex) + sectionProgress) / Double(total)
        return ReadingLocator(
            overall: min(1, max(0, overall)),
            chapterIndex: sectionIndex,
            chapterProgress: sectionProgress,
            pageIndex: 0
        )
    }

    // MARK: - 加载

    func load() {
        let book = self.book
        let fileURL = LibraryStore.shared.fileURL(for: book)
        let workDirectory = LibraryStore.shared.directory(for: book)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let document = try BookLoader.load(
                    book: book,
                    fileURL: fileURL,
                    workDirectory: workDirectory,
                    readAccessRoot: LibraryStore.shared.rootURL
                )
                DispatchQueue.main.async {
                    self.apply(document)
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func apply(_ document: ReadingDocument) {
        self.document = document
        if book.format != .pdf {
            if sectionIndex >= document.sections.count {
                sectionIndex = max(0, document.sections.count - 1)
            }
            if sectionIndex < 0 { sectionIndex = 0 }
        }
        pageIndex = 0
        pageCount = 0
        isLoading = false
        persistNow()
        prepareSection(sectionIndex)
    }

    /// 网络书：章节正文按需抓取并缓存，缓存好后递增 reloadToken 触发重载。
    func prepareSection(_ index: Int) {
        guard book.isNetworkBook else { return }
        let chapters = LibraryStore.shared.chapters(for: book)
        guard index >= 0, index < chapters.count else { return }
        if ChapterCache.isCached(bookID: book.id, index: index) { return }
        guard !loadingIndexes.contains(index) else { return }
        guard let sourceID = book.sourceID,
              let source = BookSourceStore.shared.source(id: sourceID) else {
            chapterError = "书源已被删除，无法加载本章"
            return
        }

        let chapter = chapters[index]
        let bookID = book.id
        loadingIndexes.insert(index)
        isLoadingChapter = true

        Task { [weak self] in
            do {
                let content = try await BookSourceEngine.content(
                    source: source,
                    chapterURL: chapter.url,
                    title: chapter.title
                )
                let html = BookSourceEngine.chapterHTML(title: chapter.title, content: content)
                ChapterCache.save(html: html, bookID: bookID, index: index)
                await MainActor.run {
                    guard let self = self else { return }
                    self.loadingIndexes.remove(index)
                    self.isLoadingChapter = false
                    self.reloadToken += 1
                }
            } catch {
                await MainActor.run {
                    guard let self = self else { return }
                    self.loadingIndexes.remove(index)
                    self.isLoadingChapter = false
                    self.chapterError = error.localizedDescription
                }
            }
        }
    }

    func updatePages(current: Int, total: Int) {
        if pageCount != total { pageCount = total }
        if pageIndex != current {
            sessionPageTurns += 1
            pageIndex = current
        }
    }

    func consumePageTurns() -> Int {
        let value = sessionPageTurns
        sessionPageTurns = 0
        return value
    }

    // MARK: - 进度

    func updateSectionProgress(_ value: Double) {
        let clamped = min(max(value, 0), 1)
        guard abs(clamped - sectionProgress) > 0.0002 else { return }
        sectionProgress = clamped
        schedulePersist()
    }

    func updatePDFPage(_ index: Int, count: Int) {
        pdfPageCount = count
        guard index != pdfPageIndex else { return }
        pdfPageIndex = index
        schedulePersist()
    }

    @discardableResult
    func goToSection(_ index: Int) -> Bool {
        guard let document = document else { return false }
        guard index >= 0, index < document.sections.count else { return false }
        guard index != sectionIndex else { return false }
        sectionIndex = index
        sectionProgress = 0
        pageIndex = 0
        pageCount = 0
        sessionPageTurns += 1
        persistNow()
        prepareSection(index)
        return true
    }

    func jumpTo(chapterIndex: Int, progress: Double) {
        let target = max(0, min(1, progress))
        if chapterIndex != sectionIndex {
            sectionIndex = max(0, chapterIndex)
        }
        sectionProgress = target
        pageIndex = 0
        pageCount = 0
        highlightTerm = ""
        highlightToken += 1
        reloadToken += 1
        prepareSection(sectionIndex)
        persistNow()
    }

    func jump(to hit: BookSearchHit, keyword: String) {
        highlightTerm = keyword
        highlightToken += 1
        goToSection(hit.chapterIndex)
    }

    @discardableResult
    func addBookmarkNow() -> Bookmark {
        let mark = Bookmark(
            chapterIndex: sectionIndex,
            chapterTitle: currentSection?.title ?? "第 \(sectionIndex + 1) 章",
            progress: sectionProgress,
            pageIndex: ReadingSettings.shared.pageMode ? pageIndex : 0
        )
        LibraryStore.shared.addBookmark(mark, for: book)
        return mark
    }

    func nextSection() {
        goToSection(sectionIndex + 1)
    }

    func previousSection() {
        goToSection(sectionIndex - 1)
    }

    // MARK: - 持久化

    private func schedulePersist() {
        if Date().timeIntervalSince(lastPersist) > 3 {
            persistNow()
            return
        }
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.persistNow()
        }
        pendingSave = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    func persistNow() {
        pendingSave?.cancel()
        pendingSave = nil
        let locator = currentLocator
        LibraryStore.shared.updateLocator(locator, for: book.id)
        lastPersist = Date()
    }
}