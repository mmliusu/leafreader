import Foundation

/// Legado / 阅读3.0 书源。所有字段可选，兼容字段缺失与字符串形式的 rule。
struct BookSource: Codable, Identifiable, Equatable {
    var bookSourceUrl: String
    var bookSourceName: String
    var bookSourceGroup: String?
    var bookSourceComment: String?
    var bookSourceType: Int?
    var enabled: Bool?
    var header: String?
    var searchUrl: String?
    var exploreUrl: String?
    var jsLib: String?
    var weight: Int?
    var ruleSearch: BookListRule?
    var ruleBookInfo: BookInfoRule?
    var ruleToc: TocRule?
    var ruleContent: ContentRule?

    var id: String { bookSourceUrl }

    var isEnabled: Bool { enabled ?? true }
    var groupName: String {
        let value = (bookSourceGroup ?? "").trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? "未分组" : value
    }
    var displayName: String {
        let value = bookSourceName.trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? bookSourceUrl : value
    }
    var isTextSource: Bool { (bookSourceType ?? 0) == 0 }
    var canSearch: Bool { !(searchUrl ?? "").isEmpty }
    var host: String {
        URL(string: bookSourceUrl)?.host ?? bookSourceUrl
    }
}

struct BookListRule: Codable, Equatable {
    var bookList: String?
    var name: String?
    var author: String?
    var kind: String?
    var wordCount: String?
    var lastChapter: String?
    var intro: String?
    var coverUrl: String?
    var bookUrl: String?
    var checkKeyWord: String?
}

struct BookInfoRule: Codable, Equatable {
    var name: String?
    var author: String?
    var kind: String?
    var wordCount: String?
    var lastChapter: String?
    var intro: String?
    var coverUrl: String?
    var tocUrl: String?
    var canReName: String?
}

struct TocRule: Codable, Equatable {
    var chapterList: String?
    var chapterName: String?
    var chapterUrl: String?
    var isVip: String?
    var updateTime: String?
    var nextTocUrl: String?
}

struct ContentRule: Codable, Equatable {
    var content: String?
    var nextContentUrl: String?
    var webJs: String?
    var sourceRegex: String?
    var title: String?
    var imageStyle: String?
}

/// 搜索结果
struct SourceSearchResult: Identifiable, Equatable {
    var id: String { "\(sourceID)|\(bookUrl)" }
    var sourceID: String
    var sourceName: String
    var name: String
    var author: String
    var coverUrl: String?
    var intro: String?
    var kind: String?
    var lastChapter: String?
    var bookUrl: String
}

/// 发现页分类
struct ExploreCategory: Identifiable, Equatable {
    var index: Int
    var title: String
    var url: String
    var id: String { "\(index)|\(title)" }
}

/// 网络书章节
struct SourceChapter: Identifiable, Equatable, Codable {
    var id: Int
    var title: String
    var url: String
    var isVip: Bool
    var cached: Bool = false
}

/// 书籍详情（搜索结果 + 详情页补充）
struct SourceBookDetail {
    var source: BookSource
    var name: String
    var author: String
    var coverUrl: String?
    var intro: String?
    var kind: String?
    var lastChapter: String?
    var bookUrl: String
    var tocUrl: String
    var chapters: [SourceChapter]

    var key: String { "\(source.bookSourceUrl)|\(bookUrl)" }
}