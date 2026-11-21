import Foundation

private struct TextSectionRecord: Codable {
    var title: String
    var fileName: String
}

private struct TextSectionIndex: Codable {
    var sourceSize: Int64
    var sourceModified: Double
    var sections: [TextSectionRecord]
}

/// 把 TXT 转成按段落渲染的 HTML，并按字符数切成若干段，避免超大文件撑爆 WKWebView。
enum TextBookBuilder {
    private static let sectionCharLimit = 60_000

    static func build(sourceURL: URL, outputDirectory: URL) throws -> [ReadingSection] {
        let fm = FileManager.default
        try fm.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let attributes = try? fm.attributesOfItem(atPath: sourceURL.path)
        let modified = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        let indexURL = outputDirectory.appendingPathComponent("sections.json")

        if let data = try? Data(contentsOf: indexURL),
           let cached = try? JSONDecoder().decode(TextSectionIndex.self, from: data),
           cached.sourceSize == size,
           abs(cached.sourceModified - modified) < 1 {
            var sections: [ReadingSection] = []
            for (offset, record) in cached.sections.enumerated() {
                let url = outputDirectory.appendingPathComponent(record.fileName)
                guard fm.fileExists(atPath: url.path) else { continue }
                sections.append(ReadingSection(id: offset, title: record.title, url: url))
            }
            if sections.count == cached.sections.count {
                return sections
            }
        }

        let text = TextDecoder.decode(contentsOf: sourceURL)
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let chunks = split(normalized)
        var records: [TextSectionRecord] = []
        var sections: [ReadingSection] = []

        for (index, chunk) in chunks.enumerated() {
            let fileName = String(format: "section-%04d.html", index)
            let url = outputDirectory.appendingPathComponent(fileName)
            try htmlDocument(body: chunk).write(to: url, atomically: true, encoding: .utf8)
            let title = sectionTitle(from: chunk, index: index, total: chunks.count)
            records.append(TextSectionRecord(title: title, fileName: fileName))
            sections.append(ReadingSection(id: index, title: title, url: url))
        }

        let index = TextSectionIndex(sourceSize: size, sourceModified: modified, sections: records)
        if let data = try? JSONEncoder().encode(index) {
            try? data.write(to: indexURL, options: .atomic)
        }
        return sections
    }

    // MARK: - 内部

    private static func split(_ text: String) -> [String] {
        var chunks: [String] = []
        var buffer: [String] = []
        var length = 0

        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let string = String(line)
            if length + string.count > sectionCharLimit && length > 0 {
                chunks.append(buffer.joined(separator: "\n"))
                buffer.removeAll(keepingCapacity: true)
                length = 0
            }
            buffer.append(string)
            length += string.count + 1
        }
        if !buffer.isEmpty {
            chunks.append(buffer.joined(separator: "\n"))
        }
        if chunks.isEmpty {
            chunks = [text]
        }
        return chunks
    }

    private static func sectionTitle(from chunk: String, index: Int, total: Int) -> String {
        for line in chunk.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = String(line).trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let prefix = trimmed.count > 24 ? String(trimmed.prefix(24)) + "…" : trimmed
            return prefix
        }
        return total > 1 ? "第 \(index + 1) 部分" : "正文"
    }

    private static func htmlDocument(body: String) -> String {
        var parts: [String] = []
        var lastWasGap = false

        for line in body.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = String(line).trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if !lastWasGap && !parts.isEmpty {
                    parts.append("<div class=\"leaf-gap\"></div>")
                }
                lastWasGap = true
            } else {
                parts.append("<p class=\"leaf-p\">\(escape(trimmed))</p>")
                lastWasGap = false
            }
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>
        html, body { background: #FFFFFF; color: #1A1A1A; margin: 0; padding: 0; }
        .leaf-p { margin: 0 0 0.75em 0; text-indent: 2em; }
        .leaf-gap { height: 0.4em; }
        </style>
        </head>
        <body>
        \(parts.joined(separator: "\n"))
        </body>
        </html>
        """
    }

    private static func escape(_ text: String) -> String {
        var result = text.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        return result
    }
}