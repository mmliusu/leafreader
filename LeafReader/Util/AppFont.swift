import SwiftUI
import UIKit

enum UIFontChoice: String, CaseIterable, Identifiable {
    case jinling
    case system
    case songti
    case kaiti
    case pingfang

    var id: String { rawValue }

    var title: String {
        switch self {
        case .jinling: return "金陵"
        case .system: return "系统"
        case .songti: return "宋体"
        case .kaiti: return "楷体"
        case .pingfang: return "黑体"
        }
    }

    /// 依次尝试的 PostScript 名，取第一个实际存在的
    var candidates: [String] {
        switch self {
        case .jinling: return ["FZXIJINLJW--GB1-0"]
        case .system: return []
        case .songti: return ["STSongti-SC-Regular", "Songti SC"]
        case .kaiti: return ["STKaiti-SC-Regular", "Kaiti SC"]
        case .pingfang: return ["PingFangSC-Regular", "PingFang SC"]
        }
    }
}

/// 全局界面字体：读 UserDefaults 的 ui.font / ui.scale，切换后由根视图重建生效。
enum AppFont {
    static let fontKey = "ui.font"
    static let baseKey = "ui.base"

    private static var cachedChoice: UIFontChoice?
    private static var cachedName: String?

    /// 界面基准字号（正文 16pt），其它字号按比例缩放
    static var base: CGFloat {
        let value = UserDefaults.standard.double(forKey: baseKey)
        return value >= 12 ? CGFloat(value) : 16
    }

    static var choice: UIFontChoice {
        UIFontChoice(rawValue: UserDefaults.standard.string(forKey: fontKey) ?? "") ?? .jinling
    }

    static func resolvedName() -> String? {
        let current = choice
        if cachedChoice == current {
            return cachedName
        }
        var found: String?
        for name in current.candidates where UIFont(name: name, size: 16) != nil {
            found = name
            break
        }
        cachedChoice = current
        cachedName = found
        return found
    }

    static func size(_ value: CGFloat) -> Font {
        let target = value * base / 16
        if let name = resolvedName() {
            return .custom(name, size: target)
        }
        return .system(size: target)
    }

    static var title: Font { size(30) }
    static var title3: Font { size(21) }
    static var headline: Font { size(18) }
    static var body: Font { size(16) }
    static var callout: Font { size(15) }
    static var subheadline: Font { size(14) }
    static var footnote: Font { size(13) }
    static var caption: Font { size(12) }
    static var caption2: Font { size(11) }
}