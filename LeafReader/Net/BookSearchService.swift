import Foundation

struct BookSearchHit: Identifiable, Equatable {
    var chapterIndex: Int
    var chapterTitle: String
    var snippet: String

    var id: String { "\(chapterIndex)|\(snippet)" }
}

/// 跨章节全文搜索。只搜本地已存在的章节文件（网络书未缓存的章节会被跳过）。
enum BookSearchService {

    static func search(keyword: String, sections: [ReadingSection], limit: Int = 80) async -> [BookSearchHit] {
        let term = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 1 else { return [] }

        var hits: [BookSearchHit] = []
        for section in sections {
            if hits.count >= limit { break }
            guard let html = try? String(contentsOf: section.url, encoding: .utf8) else { continue }
            let title = section.title

            let text = plainText(from: html)
            let lower = text.lowercased()
            let query = term.lowercased()
            var searchStart = lower.startIndex
            var perChapter = 0

            while perChapter < 6, let range = lower.range(of: query, range: searchStart..<lower.endIndex) {
                let offset = text.distance(from: text.startIndex, to: range.lowerBound)
                let snippet = self.snippet(in: text, around: offset, length: term.count)
                hits.append(
                    BookSearchHit(
                        chapterIndex: section.id,
                        chapterTitle: title,
                        snippet: snippet
                    )
                )
                searchStart = range.upperBound
                perChapter += 1
                if hits.count >= limit { break }
            }
        }
        return hits
    }

    static func plainText(from html: String) -> String {
        var text = html
        let replacements: [(String, String)] = [
            ("<br>", "\n"), ("<br/>", "\n"), ("<br />", "\n"),
            ("</p>", "\n"), ("</div>", "\n"), ("</h1>", "\n"), ("</h2>", "\n"), ("</h3>", "\n"),
            ("</li>", "\n"), ("</tr>", "\n")
        ]
        for (pattern, replacement) in replacements {
            text = text.replacingOccurrences(of: pattern, with: replacement, options: .caseInsensitive)
        }
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")

        var lines: [String] = []
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { lines.append(trimmed) }
        }
        return lines.joined(separator: "\n")
    }

    private static func snippet(in text: String, around offset: Int, length: Int) -> String {
        let start = max(0, offset - 28)
        let end = min(text.count, offset + length + 34)
        let from = text.index(text.startIndex, offsetBy: start)
        let to = text.index(text.startIndex, offsetBy: end)
        var value = String(text[from..<to])
        value = value.replacingOccurrences(of: "\n", with: " ")
        return (start > 0 ? "…" : "") + value + (end < text.count ? "…" : "")
    }
}