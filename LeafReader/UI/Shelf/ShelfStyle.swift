import SwiftUI

/// 书架页视觉体系：蓝 + 中性灰，白卡（深色为深灰卡），与统计页共用同一套语言。
enum ShelfStyle {
    static let accent = Color(hex: "#2E86DE")
    static let accentSoft = Color(hex: "#2E86DE").opacity(0.12)

    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#131313") : Color(hex: "#FAFAFA")
    }

    static func card(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#2A2A2A") : .white
    }

    static func inset(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#333A42") : Color(hex: "#EEF4FC")
    }

    static func primaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#E8E8E8") : Color(hex: "#444444")
    }

    static func secondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "#9A9A9A") : Color(hex: "#8A8F99")
    }

    static func separator(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }
}

/// 顶部筛选：全部 / 在读 / 未读 / 已读 / 未分类
enum ShelfFilter: String, CaseIterable, Identifiable {
    case all
    case reading
    case unread
    case finished
    case uncategorized

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .reading: return "在读"
        case .unread: return "未读"
        case .finished: return "已读"
        case .uncategorized: return "未分类"
        }
    }

    var symbol: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .reading: return "book"
        case .unread: return "book.closed"
        case .finished: return "checkmark.circle"
        case .uncategorized: return "questionmark.folder"
        }
    }

    func matches(_ book: Book) -> Bool {
        switch self {
        case .all:
            return true
        case .reading:
            return book.lastOpenedAt != nil && book.progress > 0.001 && book.progress < 0.995
        case .unread:
            return book.lastOpenedAt == nil || book.progress <= 0.001
        case .finished:
            return book.progress >= 0.995
        case .uncategorized:
            return book.sourceID == nil
        }
    }
}

enum ShelfViewMode: String, CaseIterable, Identifiable {
    case grid
    case list
    case plain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .grid: return "网格"
        case .list: return "列表"
        case .plain: return "无图列表"
        }
    }

    var symbol: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet.rectangle"
        case .plain: return "list.bullet"
        }
    }
}

enum ShelfSortKey: String, CaseIterable, Identifiable {
    case recent
    case added
    case size
    case title
    case progress
    case duration

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: return "最后阅读"
        case .added: return "添加时间"
        case .size: return "大小"
        case .title: return "名称"
        case .progress: return "评分"
        case .duration: return "阅读时长"
        }
    }
}

enum ShelfTopStyle: String, CaseIterable, Identifiable {
    case off
    case recent
    case simulated
    case spines
    case today

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "关闭"
        case .recent: return "最近阅读"
        case .simulated: return "仿真书架"
        case .spines: return "书脊书架"
        case .today: return "今日统计"
        }
    }

    var detail: String {
        switch self {
        case .off: return "不显示书架顶部内容"
        case .recent: return "展示最近阅读书籍、进度和阅读时长"
        case .simulated: return "用最近阅读书籍模拟摆放在书架上"
        case .spines: return "用竖排书脊展示最近阅读"
        case .today: return "今天读了多少、翻了多少页"
        }
    }

    var symbol: String {
        switch self {
        case .off: return "rectangle.slash"
        case .recent: return "clock.arrow.circlepath"
        case .simulated: return "books.vertical"
        case .spines: return "square.stack.3d.up"
        case .today: return "chart.bar.xaxis"
        }
    }
}

enum ShelfQuickAction: String, CaseIterable, Identifiable {
    case toggleTheme
    case appearance
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .toggleTheme: return "切换日夜模式"
        case .appearance: return "外观设置"
        case .none: return "无"
        }
    }
}

/// 书架分类：网络书归到书源名，本地书归到「本地」。
enum ShelfCategory {
    static let local = "本地"

    static func title(for book: Book, sources: BookSourceStore) -> String {
        guard let id = book.sourceID, let source = sources.source(id: id) else { return local }
        let name = source.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? local : name
    }
}