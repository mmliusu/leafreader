import SwiftUI
import UIKit

/// 全局界面字体：方正细金陵简体（随 App 打包，PostScript 名 FZXIJINLJW--GB1-0）。
enum AppFont {
    static let postScriptName = "FZXIJINLJW--GB1-0"

    /// 不同来源的字体文件命名可能不一致，取不到 PostScript 名时退回已注册的字体名。
    static let resolvedName: String = {
        if UIFont(name: postScriptName, size: 16) != nil {
            return postScriptName
        }
        for family in UIFont.familyNames.sorted() {
            let names = UIFont.fontNames(forFamilyName: family)
            if let match = names.first(where: { $0.uppercased().contains("JIN") || $0.contains("金陵") }) {
                return match
            }
        }
        return postScriptName
    }()

    static func size(_ value: CGFloat) -> Font {
        .custom(resolvedName, size: value)
    }

    static let title = size(30)
    static let title3 = size(21)
    static let headline = size(18)
    static let body = size(16)
    static let callout = size(15)
    static let subheadline = size(14)
    static let footnote = size(13)
    static let caption = size(12)
    static let caption2 = size(11)
}