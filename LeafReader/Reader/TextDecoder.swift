import Foundation
import CoreFoundation

/// TXT 编码探测：BOM → UTF-8 → GB18030（中文 txt 主流）→ UTF-16 → Latin1。
enum TextDecoder {
    /// 0x0632 = kCFStringEncodingGB_18030_2000
    static let gb18030: String.Encoding = {
        let cf = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(0x0632))
        return String.Encoding(rawValue: cf)
    }()

    /// 0x0A03 = kCFStringEncodingBig5
    static let big5: String.Encoding = {
        let cf = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(0x0A03))
        return String.Encoding(rawValue: cf)
    }()

    static func decode(contentsOf url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return "" }
        return decode(data)
    }

    static func decode(_ data: Data) -> String {
        if data.isEmpty { return "" }

        if data.starts(with: [0xEF, 0xBB, 0xBF] as [UInt8]) {
            if let value = String(data: data.dropFirst(3), encoding: .utf8) { return value }
        }
        if data.starts(with: [0xFF, 0xFE] as [UInt8]) {
            if let value = String(data: data.dropFirst(2), encoding: .utf16LittleEndian) { return value }
        }
        if data.starts(with: [0xFE, 0xFF] as [UInt8]) {
            if let value = String(data: data.dropFirst(2), encoding: .utf16BigEndian) { return value }
        }

        if let value = String(data: data, encoding: .utf8) {
            return value
        }

        // 无 BOM 的 UTF-16 常见于 Windows 导出的 txt：ASCII 字符后跟 0x00。
        if data.count > 8, data[1] == 0, data[3] == 0,
           let value = String(data: data, encoding: .utf16LittleEndian) {
            return value
        }

        for encoding in [gb18030, .utf16, big5] {
            if let value = String(data: data, encoding: encoding), !value.isEmpty, !hasReplacementChar(value) {
                return value
            }
        }

        return String(data: data, encoding: .isoLatin1) ?? ""
    }

    private static func hasReplacementChar(_ text: String) -> Bool {
        let sample = text.prefix(3000)
        guard !sample.isEmpty else { return true }
        return sample.contains("\u{FFFD}")
    }
}