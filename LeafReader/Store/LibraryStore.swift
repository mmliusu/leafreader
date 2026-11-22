import Foundation
import PDFKit

/// 书库存储：文件放在 Application Support/LeafReader/Books/<id>/，元数据存在 library.json。
final class LibraryStore: ObservableObject {
    static let shared = LibraryStore()

    @Published private(set) var books: [Book] = []
    @Published var lastError: String?

    let rootURL: URL
    let booksURL: URL
    private let indexURL: URL
    private let fm = FileManager.default
    private var lastIncomingKey: String?
    private var lastIncomingDate = Date.distantPast
    /// 打包在 App 里的自定义字体，首次启动复制到 Application Support，供 WKWebView 用 file:// 引用。
    private(set) var customFontURL: URL?

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        rootURL = base.appendingPathComponent("LeafReader", isDirectory: true)
        booksURL = rootURL.appendingPathComponent("Books", isDirectory: true)
        indexURL = rootURL.appendingPathComponent("library.json")
        try? FileManager.default.createDirectory(at: booksURL, withIntermediateDirectories: true)

        let fontsDirectory = rootURL.appendingPathComponent("Fonts", isDirectory: true)
        try? FileManager.default.createDirectory(at: fontsDirectory, withIntermediateDirectories: true)
        let fontDestination = fontsDirectory.appendingPathComponent("FZXiJinLing.ttf")
        if !FileManager.default.fileExists(atPath: fontDestination.path),
           let source = Bundle.main.url(forResource: "FZXiJinLing", withExtension: "ttf") {
            try? FileManager.default.copyItem(at: source, to: fontDestination)
        }
        customFontURL = FileManager.default.fileExists(atPath: fontDestination.path) ? fontDestination : nil

        loadIndex()
        pruneMissing()
    }

    // MARK: - 路径

    func directory(for book: Book) -> URL {
        booksURL.appendingPathComponent(book.id.uuidString, isDirectory: true)
    }

    func fileURL(for book: Book) -> URL {
        directory(for: book).appendingPathComponent(book.fileName)
    }

    func coverURL(for book: Book) -> URL? {
        guard let name = book.coverFileName else { return nil }
        let url = directory(for: book).appendingPathComponent(name)
        return fm.fileExists(atPath: url.path) ? url : nil
    }

    var sortedBooks: [Book] {
        books.sorted { lhs, rhs in
            let l = lhs.lastOpenedAt ?? lhs.addedAt
            let r = rhs.lastOpenedAt ?? rhs.addedAt
            return l > r
        }
    }

    // MARK: - 导入

    /// 由“用其他应用打开”触发，做 2 秒内的重复调用去重（SwiftUI 的 onOpenURL 与 AppDelegate 可能同时触发）。
    func importIncomingFile(at url: URL) {
        let key = url.absoluteString
        let now = Date()
        if lastIncomingKey == key, now.timeIntervalSince(lastIncomingDate) < 2 {
            return
        }
        lastIncomingKey = key
        lastIncomingDate = now
        _ = importBook(from: url)
    }

    @discardableResult
    func importBook(from url: URL) -> Book? {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let rawName = url.lastPathComponent
        let ext = (rawName as NSString).pathExtension
        guard let format = BookFormat.from(fileExtension: ext) else {
            lastError = "暂不支持该文件类型，目前支持 TXT、EPUB、PDF。"
            return nil
        }

        let sizeValue = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        let size = Int64(sizeValue)

        if let existing = books.first(where: { $0.fileName == rawName && $0.fileSize == size }) {
            return existing
        }

        let bookID = UUID()
        let dir = booksURL.appendingPathComponent(bookID.uuidString, isDirectory: true)
        let fileName = sanitizedFileName(rawName)
        let dest = dir.appendingPathComponent(fileName)

        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            try fm.copyItem(at: url, to: dest)
        } catch {
            try? fm.removeItem(at: dir)
            lastError = "导入失败：\(error.localizedDescription)"
            return nil
        }

        var title = cleanTitle(rawName)
        var author = ""
        var coverName: String?
        var pageCount: Int?

        switch format {
        case .pdf:
            if let document = PDFDocument(url: dest) {
                pageCount = document.pageCount
                if let value = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String,
                   !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    title = value
                }
                if let value = document.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String,
                   !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    author = value
                }
            }
        case .epub:
            if let meta = EpubParser.readMetadata(archiveAt: dest) {
                if let value = meta.title, !value.isEmpty { title = value }
                if let value = meta.author, !value.isEmpty { author = value }
                if let entryPath = meta.coverEntryPath {
                    let ext = (entryPath as NSString).pathExtension
                    let coverFileName = ext.isEmpty ? "cover.jpg" : "cover.\(ext)"
                    if EpubParser.extractEntry(entryPath, fromArchiveAt: dest, to: dir.appendingPathComponent(coverFileName)) {
                        coverName = coverFileName
                    }
                }
            }
        case .txt:
            break
        }

        let book = Book(
            id: bookID,
            title: title,
            author: author,
            format: format,
            fileName: fileName,
            fileSize: size,
            coverFileName: coverName,
            pageCount: pageCount
        )

        books.insert(book, at: 0)
        saveIndex()
        return book
    }

    // MARK: - 网络书

    @discardableResult
    func addNetworkBook(detail: SourceBookDetail) -> Book {
        if let existing = books.first(where: {
            $0.sourceID == detail.source.bookSourceUrl && $0.bookUrl == detail.bookUrl
        }) {
            return existing
        }

        let id = UUID()
        let dir = booksURL.appendingPathComponent(id.uuidString, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let chaptersFileName = "chapters.json"
        if let data = try? JSONEncoder().encode(detail.chapters) {
            try? data.write(to: dir.appendingPathComponent(chaptersFileName), options: .atomic)
        }

        let book = Book(
            id: id,
            title: detail.name,
            author: detail.author,
            format: .txt,
            fileName: chaptersFileName,
            fileSize: 0,
            sourceID: detail.source.bookSourceUrl,
            bookUrl: detail.bookUrl,
            chaptersFileName: chaptersFileName,
            chapterCount: detail.chapters.count,
            coverURLString: detail.coverUrl
        )
        books.insert(book, at: 0)
        saveIndex()
        return book
    }

    func chapters(for book: Book) -> [SourceChapter] {
        guard let name = book.chaptersFileName else { return [] }
        let url = directory(for: book).appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url),
              let chapters = try? JSONDecoder().decode([SourceChapter].self, from: data) else {
            return []
        }
        return chapters
    }

    func saveChapters(_ chapters: [SourceChapter], for book: Book) {
        guard let name = book.chaptersFileName else { return }
        let url = directory(for: book).appendingPathComponent(name)
        if let data = try? JSONEncoder().encode(chapters) {
            try? data.write(to: url, options: .atomic)
        }
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books[index].chapterCount = chapters.count
            saveIndex()
        }
    }

    // MARK: - 更新

    func updateLocator(_ locator: ReadingLocator, for bookID: UUID) {
        guard let index = books.firstIndex(where: { $0.id == bookID }) else { return }
        if books[index].locator == locator { return }
        books[index].locator = locator
        saveIndex()
    }

    func markOpened(_ bookID: UUID) {
        guard let index = books.firstIndex(where: { $0.id == bookID }) else { return }
        books[index].lastOpenedAt = Date()
        saveIndex()
    }

    func rename(_ book: Book, to newTitle: String) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        books[index].title = trimmed
        saveIndex()
    }

    func delete(_ book: Book) {
        try? fm.removeItem(at: directory(for: book))
        books.removeAll { $0.id == book.id }
        saveIndex()
    }

    func resetProgress(_ book: Book) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[index].locator = .start
        saveIndex()
    }

    // MARK: - 内部

    private func pruneMissing() {
        let valid = books.filter { fm.fileExists(atPath: fileURL(for: $0).path) }
        if valid.count != books.count {
            books = valid
            saveIndex()
        }
    }

    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([Book].self, from: data) {
            books = decoded
        }
    }

    private func saveIndex() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(books) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    private func cleanTitle(_ fileName: String) -> String {
        let name = (fileName as NSString).deletingPathExtension
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名" : trimmed
    }

    private func sanitizedFileName(_ name: String) -> String {
        var result = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        if result.count > 120 {
            let ext = (result as NSString).pathExtension
            let base = (result as NSString).deletingPathExtension
            let trimmed = String(base.prefix(100))
            result = ext.isEmpty ? trimmed : "\(trimmed).\(ext)"
        }
        return result.isEmpty ? "book.txt" : result
    }
}