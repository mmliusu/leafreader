import Foundation

enum BookLoaderError: LocalizedError {
    case fileMissing
    case empty

    var errorDescription: String? {
        switch self {
        case .fileMissing: return "书籍文件不存在，可能已被删除。"
        case .empty: return "这本书没有可显示的内容。"
        }
    }
}

enum BookLoader {
    static func load(book: Book, fileURL: URL, workDirectory: URL) throws -> ReadingDocument {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else {
            throw BookLoaderError.fileMissing
        }

        switch book.format {
        case .txt:
            let output = workDirectory.appendingPathComponent("text", isDirectory: true)
            let sections = try TextBookBuilder.build(sourceURL: fileURL, outputDirectory: output)
            guard !sections.isEmpty else { throw BookLoaderError.empty }
            return ReadingDocument(sections: sections, readAccessRoot: output, format: .txt)

        case .epub:
            let root = workDirectory.appendingPathComponent("epub", isDirectory: true)
            let volume = try EpubParser.readVolume(archiveAt: fileURL, rootURL: root)
            let sections = volume.sections.enumerated().map { offset, element in
                ReadingSection(id: offset, title: element.title, url: element.url)
            }
            return ReadingDocument(sections: sections, readAccessRoot: root, format: .epub)

        case .pdf:
            let section = ReadingSection(id: 0, title: book.title, url: fileURL)
            return ReadingDocument(sections: [section], readAccessRoot: workDirectory, format: .pdf)
        }
    }
}