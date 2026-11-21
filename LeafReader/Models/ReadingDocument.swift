import Foundation

/// 一个可渲染的阅读单元（EPUB 章节 / TXT 分段 / PDF 整本）。
struct ReadingSection: Identifiable, Equatable {
    let id: Int
    let title: String
    let url: URL
}

struct ReadingDocument {
    let sections: [ReadingSection]
    /// WKWebView 允许读取的根目录（保证章节间的图片、CSS 可加载）。
    let readAccessRoot: URL
    let format: BookFormat
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}