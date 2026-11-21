import Foundation

/// 支持的电子书格式。
enum BookFormat: String, Codable, CaseIterable, Identifiable {
    case txt
    case epub
    case pdf

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .txt: return "TXT"
        case .epub: return "EPUB"
        case .pdf: return "PDF"
        }
    }

    var symbolName: String {
        switch self {
        case .txt: return "text.alignleft"
        case .epub: return "book.closed"
        case .pdf: return "doc.richtext"
        }
    }

    static func from(fileExtension ext: String) -> BookFormat? {
        switch ext.lowercased() {
        case "txt", "text", "log", "md":
            return .txt
        case "epub":
            return .epub
        case "pdf":
            return .pdf
        default:
            return nil
        }
    }
}

/// 阅读位置。overall 为全书 0...1 进度，chapterIndex/chapterProgress 用于章节内精确定位。
struct ReadingLocator: Codable, Equatable {
    var overall: Double = 0
    var chapterIndex: Int = 0
    var chapterProgress: Double = 0
    var pageIndex: Int = 0

    static let start = ReadingLocator()
}

struct Book: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var author: String
    var format: BookFormat
    var fileName: String
    var fileSize: Int64
    var addedAt: Date
    var lastOpenedAt: Date?
    var locator: ReadingLocator
    var coverFileName: String?
    var pageCount: Int?

    init(
        id: UUID = UUID(),
        title: String,
        author: String = "",
        format: BookFormat,
        fileName: String,
        fileSize: Int64,
        addedAt: Date = Date(),
        lastOpenedAt: Date? = nil,
        locator: ReadingLocator = .start,
        coverFileName: String? = nil,
        pageCount: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.format = format
        self.fileName = fileName
        self.fileSize = fileSize
        self.addedAt = addedAt
        self.lastOpenedAt = lastOpenedAt
        self.locator = locator
        self.coverFileName = coverFileName
        self.pageCount = pageCount
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, author, format, fileName, fileSize
        case addedAt, lastOpenedAt, locator, coverFileName, pageCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "未命名"
        author = try c.decodeIfPresent(String.self, forKey: .author) ?? ""
        format = try c.decodeIfPresent(BookFormat.self, forKey: .format) ?? .txt
        fileName = try c.decodeIfPresent(String.self, forKey: .fileName) ?? "book.txt"
        fileSize = try c.decodeIfPresent(Int64.self, forKey: .fileSize) ?? 0
        addedAt = try c.decodeIfPresent(Date.self, forKey: .addedAt) ?? Date()
        lastOpenedAt = try c.decodeIfPresent(Date.self, forKey: .lastOpenedAt)
        locator = try c.decodeIfPresent(ReadingLocator.self, forKey: .locator) ?? .start
        coverFileName = try c.decodeIfPresent(String.self, forKey: .coverFileName)
        pageCount = try c.decodeIfPresent(Int.self, forKey: .pageCount)
    }

    var progress: Double {
        min(max(locator.overall, 0), 1)
    }

    var isFinished: Bool {
        progress >= 0.995
    }

    var displayAuthor: String {
        author.isEmpty ? format.displayName : author
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var progressText: String {
        if progress <= 0.0005 { return "未读" }
        return "\(Int((progress * 100).rounded()))%"
    }
}