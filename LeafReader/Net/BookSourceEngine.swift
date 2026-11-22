import Foundation
import SwiftSoup

enum SourceEngineError: LocalizedError {
    case emptyURL
    case badResponse
    case noChapter
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .emptyURL: return "书源没有给出可用地址"
        case .badResponse: return "网站没有返回内容（可能被拦截或域名失效）"
        case .noChapter: return "没有解析到章节，书源规则可能已失效"
        case .emptyContent: return "正文为空，可能是 VIP 章节或规则失效"
        }
    }
}

struct SourcePage {
    var url: URL
    var document: Document?
    var json: Any?
}

enum BookSourceEngine {

    // MARK: - 搜索

    static func search(source: BookSource, keyword: String, page: Int = 1) async -> [SourceSearchResult] {
        guard let template = source.searchUrl, !template.isEmpty else { return [] }
        var vars: [String: String] = ["key": keyword, "page": "\(page)"]

        var target = template
        if RuleEngine.isJSRule(target) {
            target = JSBridge.shared.evaluate(
                script: RuleEngine.jsBody(target),
                result: "",
                baseUrl: source.bookSourceUrl,
                source: source,
                vars: vars
            )
        } else {
            target = RuleEngine.expand(target, vars: vars)
        }
        target = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return [] }

        guard let result = try? await loadPage(target, source: source),
              let rule = source.ruleSearch else { return [] }

        return parseBookList(rule, page: result, source: source, vars: &vars)
    }


    static func parseBookList(
        _ rule: BookListRule,
        page result: SourcePage,
        source: BookSource,
        vars: inout [String: String]
    ) -> [SourceSearchResult] {
        let base = result.url.absoluteString
        let nodes = RuleEngine.list(
            rule.bookList ?? "",
            html: result.document,
            json: result.json,
            base: base,
            source: source,
            vars: &vars
        )

        var items: [SourceSearchResult] = []
        for node in nodes {
            var local = vars
            let name = RuleEngine.text(rule.name ?? "", node: node, html: result.document, base: base, source: source, vars: &local)
            guard !name.isEmpty else { continue }
            let author = RuleEngine.text(rule.author ?? "", node: node, html: result.document, base: base, source: source, vars: &local)
            let cover = RuleEngine.text(rule.coverUrl ?? "", node: node, html: result.document, base: base, source: source, vars: &local)
            let intro = RuleEngine.text(rule.intro ?? "", node: node, html: result.document, base: base, source: source, vars: &local)
            let kind = RuleEngine.text(rule.kind ?? "", node: node, html: result.document, base: base, source: source, vars: &local)
            let last = RuleEngine.text(rule.lastChapter ?? "", node: node, html: result.document, base: base, source: source, vars: &local)
            let urlRaw = RuleEngine.text(rule.bookUrl ?? "", node: node, html: result.document, base: base, source: source, vars: &local)
            let bookUrl = absolute(urlRaw, base: base)
            guard !bookUrl.isEmpty else { continue }

            items.append(
                SourceSearchResult(
                    sourceID: source.bookSourceUrl,
                    sourceName: source.displayName,
                    name: name,
                    author: author,
                    coverUrl: absolute(cover, base: base),
                    intro: intro.isEmpty ? nil : intro,
                    kind: kind.isEmpty ? nil : kind,
                    lastChapter: last.isEmpty ? nil : last,
                    bookUrl: bookUrl
                )
            )
            if items.count >= 60 { break }
        }
        return items
    }

    // MARK: - 发现

    static func categories(for source: BookSource) -> [ExploreCategory] {
        guard let raw = source.exploreUrl, !raw.isEmpty else { return [] }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("["),
           let data = trimmed.data(using: .utf8),
           let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            var result: [ExploreCategory] = []
            for (offset, item) in array.enumerated() {
                guard let title = item["title"] as? String, !title.isEmpty else { continue }
                let url = (item["url"] as? String) ?? ""
                result.append(ExploreCategory(index: offset, title: title, url: url))
            }
            return result
        }

        var result: [ExploreCategory] = []
        for (offset, line) in trimmed.components(separatedBy: "\n").enumerated() {
            let text = line.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            let parts = text.components(separatedBy: "::")
            guard parts.count >= 2 else { continue }
            result.append(ExploreCategory(index: offset, title: parts[0], url: parts[1]))
        }
        return result
    }

    static func exploreBooks(source: BookSource, category: ExploreCategory, page: Int) async -> [SourceSearchResult] {
        guard !category.url.isEmpty else { return [] }
        var vars: [String: String] = ["page": "\(page)", "key": ""]
        let target = RuleEngine.expand(category.url, vars: vars)
        guard let result = try? await loadPage(target, source: source) else { return [] }
        guard let rule = source.ruleExplore ?? source.ruleSearch else { return [] }
        return parseBookList(rule, page: result, source: source, vars: &vars)
    }

    // MARK: - 详情 + 目录

    static func detail(
        source: BookSource,
        bookUrl: String,
        keyword: String,
        fallback: SourceSearchResult?
    ) async throws -> SourceBookDetail {
        var vars: [String: String] = ["key": keyword, "page": "1"]
        let page = try await loadPage(bookUrl, source: source)
        let base = page.url.absoluteString

        var name = fallback?.name ?? ""
        var author = fallback?.author ?? ""
        var cover = fallback?.coverUrl
        var intro = fallback?.intro
        var kind = fallback?.kind
        var lastChapter = fallback?.lastChapter
        var tocRaw = ""

        if let rule = source.ruleBookInfo {
            let parsedName = RuleEngine.text(rule.name ?? "", node: page.document, html: page.document, base: base, source: source, vars: &vars)
            if !parsedName.isEmpty { name = parsedName }
            let parsedAuthor = RuleEngine.text(rule.author ?? "", node: page.document, html: page.document, base: base, source: source, vars: &vars)
            if !parsedAuthor.isEmpty { author = parsedAuthor }
            let parsedKind = RuleEngine.text(rule.kind ?? "", node: page.document, html: page.document, base: base, source: source, vars: &vars)
            if !parsedKind.isEmpty { kind = parsedKind }
            let parsedIntro = RuleEngine.text(rule.intro ?? "", node: page.document, html: page.document, base: base, source: source, vars: &vars)
            if !parsedIntro.isEmpty { intro = parsedIntro }
            let parsedLast = RuleEngine.text(rule.lastChapter ?? "", node: page.document, html: page.document, base: base, source: source, vars: &vars)
            if !parsedLast.isEmpty { lastChapter = parsedLast }
            let parsedCover = RuleEngine.text(rule.coverUrl ?? "", node: page.document, html: page.document, base: base, source: source, vars: &vars)
            if !parsedCover.isEmpty { cover = absolute(parsedCover, base: base) }
            tocRaw = RuleEngine.text(rule.tocUrl ?? "", node: page.document, html: page.document, base: base, source: source, vars: &vars)
        }

        if name.isEmpty { name = fallback?.name ?? "未命名" }
        let tocUrl = absolute(tocRaw, base: base).isEmpty ? bookUrl : absolute(tocRaw, base: base)
        let chapters = try await loadChapters(source: source, tocUrl: tocUrl, vars: &vars)

        return SourceBookDetail(
            source: source,
            name: name,
            author: author,
            coverUrl: cover,
            intro: intro,
            kind: kind,
            lastChapter: lastChapter,
            bookUrl: bookUrl,
            tocUrl: tocUrl,
            chapters: chapters
        )
    }

    static func loadChapters(source: BookSource, tocUrl: String, vars: inout [String: String]) async throws -> [SourceChapter] {
        var chapters: [SourceChapter] = []
        var next = tocUrl
        var hops = 0

        while !next.isEmpty && hops < 12 {
            guard let page = try? await loadPage(next, source: source) else { break }
            let base = page.url.absoluteString
            guard let rule = source.ruleToc else { break }

            let nodes = RuleEngine.list(
                rule.chapterList ?? "",
                html: page.document,
                json: page.json,
                base: base,
                source: source,
                vars: &vars
            )

            for node in nodes {
                var local = vars
                let title = RuleEngine.text(rule.chapterName ?? "text", node: node, html: page.document, base: base, source: source, vars: &local)
                let urlRaw = RuleEngine.text(rule.chapterUrl ?? "href", node: node, html: page.document, base: base, source: source, vars: &local)
                let chapterURL = absolute(urlRaw, base: base)
                guard !chapterURL.isEmpty else { continue }
                let isVip = !RuleEngine.text(rule.isVip ?? "", node: node, html: page.document, base: base, source: source, vars: &local).isEmpty
                chapters.append(
                    SourceChapter(
                        id: chapters.count,
                        title: title.isEmpty ? "第 \(chapters.count + 1) 章" : title,
                        url: chapterURL,
                        isVip: isVip
                    )
                )
            }

            let nextRule = rule.nextTocUrl ?? ""
            if nextRule.isEmpty { break }
            let nextRaw = RuleEngine.text(nextRule, node: page.document, html: page.document, base: base, source: source, vars: &vars)
            let resolved = absolute(nextRaw, base: base)
            if resolved.isEmpty || resolved == next { break }
            next = resolved
            hops += 1
        }

        guard !chapters.isEmpty else { throw SourceEngineError.noChapter }
        return chapters
    }

    // MARK: - 正文

    static func content(source: BookSource, chapterURL: String, title: String) async throws -> String {
        var vars: [String: String] = ["title": title]
        var pieces: [String] = []
        var next = chapterURL
        var hops = 0

        while !next.isEmpty && hops < 5 {
            let page = try await loadPage(next, source: source)
            let base = page.url.absoluteString
            let rule = source.ruleContent
            let raw = RuleEngine.text(rule?.content ?? "", node: page.document, html: page.document, base: base, source: source, vars: &vars)
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { pieces.append(trimmed) }

            let nextRule = rule?.nextContentUrl ?? ""
            if nextRule.isEmpty { break }
            let nextRaw = RuleEngine.text(nextRule, node: page.document, html: page.document, base: base, source: source, vars: &vars)
            let resolved = absolute(nextRaw, base: base)
            if resolved.isEmpty || resolved == next { break }
            next = resolved
            hops += 1
        }

        guard !pieces.isEmpty else { throw SourceEngineError.emptyContent }
        return pieces.joined(separator: "\n")
    }

    // MARK: - 页面加载

    static func loadPage(_ urlText: String, source: BookSource) async throws -> SourcePage {
        guard let request = SourceRequest(raw: urlText, base: source.bookSourceUrl) else {
            throw SourceEngineError.emptyURL
        }
        let text = try await SourceHTTP.fetch(request, source: source)
        guard !text.isEmpty else { throw SourceEngineError.badResponse }
        return parse(text, url: request.url)
    }

    static func parse(_ text: String, url: URL) -> SourcePage {
        var page = SourcePage(url: url, document: nil, json: nil)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            if let data = trimmed.data(using: .utf8),
               let object = try? JSONSerialization.jsonObject(with: data) {
                page.json = object
            }
        }
        if page.json == nil {
            page.document = try? SwiftSoup.parse(text, url.absoluteString)
        }
        return page
    }

    static func absolute(_ raw: String, base: String?) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }
        if text.hasPrefix("//") { text = "https:" + text }
        if text.hasPrefix("http://") || text.hasPrefix("https://") { return text }
        guard let base = base else { return "" }
        return SourceRequest.resolveURL(text, base: base)?.absoluteString ?? ""
    }

    // MARK: - 章节 HTML

    static func chapterHTML(title: String, content: String) -> String {
        let safeTitle = escape(title)
        let body: String
        if content.contains("<p") || content.contains("<br") || content.contains("</div>") {
            body = content
        } else {
            let escaped = escape(content)
            body = escaped
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { "<p>\($0)</p>" }
                .joined()
        }
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        </head>
        <body>
        <h3 class="leaf-chapter-title">\(safeTitle)</h3>
        \(body)
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

// MARK: - 章节缓存

enum ChapterCache {
    static func directory(for bookID: UUID) -> URL {
        LibraryStore.shared.booksURL
            .appendingPathComponent(bookID.uuidString, isDirectory: true)
            .appendingPathComponent("chapters", isDirectory: true)
    }

    static func htmlURL(for bookID: UUID, index: Int) -> URL {
        directory(for: bookID).appendingPathComponent(String(format: "%05d.html", index))
    }

    static func isCached(bookID: UUID, index: Int) -> Bool {
        FileManager.default.fileExists(atPath: htmlURL(for: bookID, index: index).path)
    }

    static func save(html: String, bookID: UUID, index: Int) {
        let dir = directory(for: bookID)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? html.write(to: htmlURL(for: bookID, index: index), atomically: true, encoding: .utf8)
    }

    static func load(bookID: UUID, index: Int) -> String? {
        try? String(contentsOf: htmlURL(for: bookID, index: index), encoding: .utf8)
    }

    static func clear(bookID: UUID) {
        try? FileManager.default.removeItem(at: directory(for: bookID))
    }
}