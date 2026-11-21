import SwiftUI

enum ReaderTheme: String, CaseIterable, Identifiable, Codable {
    case paper
    case sepia
    case night
    case green

    var id: String { rawValue }

    var name: String {
        switch self {
        case .paper: return "纸质"
        case .sepia: return "米黄"
        case .night: return "夜间"
        case .green: return "护眼"
        }
    }

    var backgroundHex: String {
        switch self {
        case .paper: return "#FFFFFF"
        case .sepia: return "#F5EBD8"
        case .night: return "#15171A"
        case .green: return "#DCE8D5"
        }
    }

    var foregroundHex: String {
        switch self {
        case .paper: return "#1A1A1A"
        case .sepia: return "#3B2E1E"
        case .night: return "#BFC4C9"
        case .green: return "#1F2D1F"
        }
    }

    var linkHex: String {
        switch self {
        case .night: return "#6FA8DC"
        default: return "#2A5DB0"
        }
    }

    var backgroundColor: Color {
        Color(hex: backgroundHex)
    }

    var foregroundColor: Color {
        Color(hex: foregroundHex)
    }
}

enum ReaderFont: String, CaseIterable, Identifiable {
    case jinling
    case system
    case songti
    case kaiti
    case pingfang

    var id: String { rawValue }

    var name: String {
        switch self {
        case .jinling: return "金陵"
        case .system: return "系统"
        case .songti: return "宋体"
        case .kaiti: return "楷体"
        case .pingfang: return "黑体"
        }
    }

    var cssFamily: String {
        switch self {
        case .jinling: return "\"LeafCustom\", \"FangSong\", \"STFangsong\", serif"
        case .system: return "-apple-system, \"PingFang SC\", \"Helvetica Neue\", sans-serif"
        case .songti: return "\"Songti SC\", \"STSong\", \"SimSun\", serif"
        case .kaiti: return "\"Kaiti SC\", \"STKaiti\", \"KaiTi\", serif"
        case .pingfang: return "\"PingFang SC\", \"Heiti SC\", -apple-system, sans-serif"
        }
    }
}

/// 全局阅读偏好，手动持久化到 UserDefaults，保证 @Published 能驱动 UI。
final class ReadingSettings: ObservableObject {
    static let shared = ReadingSettings()

    private let defaults = UserDefaults.standard

    @Published var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: Keys.fontSize) }
    }
    @Published var lineHeight: Double {
        didSet { defaults.set(lineHeight, forKey: Keys.lineHeight) }
    }
    @Published var margin: Double {
        didSet { defaults.set(margin, forKey: Keys.margin) }
    }
    @Published var theme: ReaderTheme {
        didSet { defaults.set(theme.rawValue, forKey: Keys.theme) }
    }
    @Published var font: ReaderFont {
        didSet { defaults.set(font.rawValue, forKey: Keys.font) }
    }
    /// true = 横向分页翻页；false = 纵向滚动
    @Published var pageMode: Bool {
        didSet { defaults.set(pageMode, forKey: Keys.pageMode) }
    }

    private enum Keys {
        static let fontSize = "reader.fontSize"
        static let lineHeight = "reader.lineHeight"
        static let margin = "reader.margin"
        static let theme = "reader.theme"
        static let font = "reader.font"
        static let pageMode = "reader.pageMode"
    }

    private init() {
        let storedSize = defaults.double(forKey: Keys.fontSize)
        fontSize = storedSize > 0 ? storedSize : 19

        let storedLine = defaults.double(forKey: Keys.lineHeight)
        lineHeight = storedLine > 0 ? storedLine : 1.75

        let storedMargin = defaults.double(forKey: Keys.margin)
        margin = storedMargin > 0 ? storedMargin : 20

        if let raw = defaults.string(forKey: Keys.theme), let value = ReaderTheme(rawValue: raw) {
            theme = value
        } else {
            theme = .paper
        }

        if let raw = defaults.string(forKey: Keys.font), let value = ReaderFont(rawValue: raw) {
            font = value
        } else {
            font = .jinling
        }

        if defaults.object(forKey: Keys.pageMode) == nil {
            pageMode = true
        } else {
            pageMode = defaults.bool(forKey: Keys.pageMode)
        }
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r, g, b, a: Double
        switch cleaned.count {
        case 8:
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        default:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}