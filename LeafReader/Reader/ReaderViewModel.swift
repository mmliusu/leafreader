import SwiftUI
import Combine

final class ReaderViewModel: ObservableObject {
    let book: Book

    @Published var document: ReadingDocument?
    @Published var sectionIndex: Int
    @Published var sectionProgress: Double
    @Published var pdfPageIndex: Int
    @Published var pdfPageCount: Int
    @Published var isLoading = true
    @Published var errorMessage: String?

    private var lastPersist = Date.distantPast
    private var pendingSave: DispatchWorkItem?

    init(book: Book) {
        self.book = book
        self.sectionIndex = max(0, book.locator.chapterIndex)
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
                let document = try BookLoader.load(book: book, fileURL: fileURL, workDirectory: workDirectory)
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
        isLoading = false
        persistNow()
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
        persistNow()
        return true
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