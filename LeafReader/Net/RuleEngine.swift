import Foundation
import SwiftSoup

/// Legado 规则求值：CSS(含三段式) / JSONPath / 正则 / @js / ##替换 / {{模板}}
enum RuleEngine {

    private static let terminalNames: Set<String> = [
        "text", "textnodes", "owntext", "html", "all", "outerhtml",
        "href", "src", "content", "value", "title", "alt",
        "data-src", "data-original", "data-id", "data-url"
    ]

    // MARK: - 列表规则

    static func list(
        _ rule: String,
        html: Document?,
        json: Any?,
        base: String?,
        source: BookSource?,
        vars: inout [String: String]
    ) -> [Any] {
        var text = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }

        var reversed = false
        if text.hasPrefix("-") {
            reversed = true
            text.removeFirst()
        }

        if isJSRule(text) {
            let input = json.map { "\($0)" } ?? (html.flatMap { try? $0.html() } ?? "")
            let output = JSBridge.shared.evaluate(
                script: jsBody(text),
                result: input,
                baseUrl: base ?? source?.bookSourceUrl ?? "",
                source: source,
                vars: vars
            )
            let parsed = splitLines(output)
            return reversed ? Array(parsed.reversed()) : parsed
        }

        text = expand(text, vars: vars, node: json)

        if text.hasPrefix(":") {
            let pattern = String(text.dropFirst())
            let body = html.flatMap { try? $0.html() } ?? ""
            let items = regexMatches(pattern, in: body)
            return reversed ? Array(items.reversed()) : items
        }

        if isJSONPath(text) {
            let root: Any = json ?? [String: Any]()
            let items = JSONPath.query(text, root: root)
            return reversed ? Array(items.reversed()) : items
        }

        if isXPath(text), let document = html {
            let items = XPathEngine.evaluate(text, in: document)
            return reversed ? Array(items.reversed()) : items
        }

        guard let document = html else { return [] }
        let rootElements: [Element] = [document]
        let (nodes, _) = select(text, from: rootElements)
        let values: [Any] = nodes.map { $0 as Any }
        return reversed ? Array(values.reversed()) : values
    }

    // MARK: - 字段规则

    static func text(
        _ rule: String,
        node: Any?,
        html: Document?,
        base: String?,
        source: BookSource?,
        vars: inout [String: String]
    ) -> String {
        let raw = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "" }

        let split = splitRegexReplace(raw)
        var value = baseValue(
            split.base,
            node: node,
            html: html,
            base: base,
            source: source,
            vars: &vars
        )

        if let pattern = split.pattern {
            value = regexReplace(value, pattern: pattern, template: split.template)
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 基础求值

    private static func baseValue(
        _ rule: String,
        node: Any?,
        html: Document?,
        base: String?,
        source: BookSource?,
        vars: inout [String: String]
    ) -> String {
        var text = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }

        if isJSRule(text) {
            let input: String
            if let element = node as? Element {
                input = (try? element.html()) ?? ""
            } else if let element = node as? Document {
                input = (try? element.html()) ?? ""
            } else {
                input = node.map { "\($0)" } ?? ""
            }
            return JSBridge.shared.evaluate(
                script: jsBody(text),
                result: input,
                baseUrl: base ?? source?.bookSourceUrl ?? "",
                source: source,
                vars: vars
            )
        }

        text = expand(text, vars: vars, node: node)

        if isJSONPath(text) {
            let root: Any = node ?? [String: Any]()
            let items = JSONPath.query(text, root: root)
            return items.map(describe).joined(separator: "\n")
        }

        if isXPath(text), let document = html ?? (node as? Document) {
            let items = XPathEngine.evaluate(text, in: document)
            return items.map(describe).joined(separator: "\n")
        }

        if text.hasPrefix(":") {
            let pattern = String(text.dropFirst())
            let body = html.flatMap { try? $0.html() } ?? ""
            return regexMatches(pattern, in: body).joined(separator: "\n")
        }

        var roots: [Element] = []
        if let element = node as? Element {
            roots = [element]
        } else if let document = html {
            roots = [document]
        } else if let document = node as? Document {
            roots = [document]
        }
        guard !roots.isEmpty else { return "" }

        let (nodes, terminal) = select(text, from: roots)
        guard let first = nodes.first else { return "" }
        return value(of: first, terminal: terminal)
    }

    // MARK: - CSS 逐级下钻（支持 class.x.0@tag.a@href 三段式）

    static func select(_ rule: String, from roots: [Element]) -> (nodes: [Element], terminal: String?) {
        var text = rule
        if text.hasPrefix("@css:") {
            text = String(text.dropFirst(5))
        } else if text.hasPrefix("@@") {
            text = String(text.dropFirst(2))
        }

        var segments = text.components(separatedBy: "@").filter { !$0.isEmpty }
        var terminal: String?
        if let last = segments.last, isTerminal(last) {
            terminal = last.lowercased()
            segments.removeLast()
        }

        var current = roots
        for segment in segments {
            let (cssRaw, index) = splitIndex(segment)
            let css = convertSegment(cssRaw)
            var next: [Element] = []
            for root in current {
                if let matched = try? root.select(css) {
                    next.append(contentsOf: matched)
                }
            }
            current = applyIndex(next, index)
            if current.isEmpty { break }
        }
        return (current, terminal)
    }

    private static func splitIndex(_ raw: String) -> (String, Index?) {
        guard let dot = raw.lastIndex(of: ".") else { return (raw, nil) }
        let tail = String(raw[raw.index(after: dot)...]).trimmingCharacters(in: .whitespaces)
        guard !tail.isEmpty else { return (raw, nil) }
        let head = String(raw[..<dot])

        if tail.hasPrefix("!") {
            let numbers = tail.dropFirst()
                .split(separator: ":")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            return (head, .exclude(numbers))
        }
        if tail.contains(":") {
            let parts = tail.split(separator: ":", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2,
                  let start = Int(parts[0]), let end = Int(parts[1]) else { return (raw, nil) }
            return (head, .range(start, end))
        }
        if tail.contains(",") {
            let numbers = tail.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            guard !numbers.isEmpty else { return (raw, nil) }
            return (head, .multi(numbers))
        }
        if let value = Int(tail) {
            return (head, .single(value))
        }
        return (raw, nil)
    }

    private enum Index {
        case single(Int)
        /// 区间，含起点不含终点（Legado 的 `0:3`）
        case range(Int, Int)
        case multi([Int])
        case exclude([Int])
    }

    private static func applyIndex(_ nodes: [Element], _ index: Index?) -> [Element] {
        guard let index = index else { return nodes }
        func position(_ value: Int) -> Int {
            value < 0 ? nodes.count + value : value
        }
        switch index {
        case .single(let value):
            let target = position(value)
            guard target >= 0, target < nodes.count else { return [] }
            return [nodes[target]]
        case .range(let start, let end):
            let lower = max(0, min(nodes.count, position(start)))
            let upper = max(lower, min(nodes.count, position(end)))
            guard lower < upper else { return [] }
            return Array(nodes[lower..<upper])
        case .multi(let values):
            return values.compactMap { value in
                let target = position(value)
                return target >= 0 && target < nodes.count ? nodes[target] : nil
            }
        case .exclude(let values):
            let excluded = Set(values.map(position))
            var result: [Element] = []
            for (offset, element) in nodes.enumerated() where !excluded.contains(offset) {
                result.append(element)
            }
            return result
        }
    }

    private static func convertSegment(_ raw: String) -> String {
        let segment = raw.trimmingCharacters(in: .whitespaces)
        guard !segment.isEmpty else { return "*" }

        if segment == "children" { return "> *" }

        if segment.hasPrefix("class.") {
            return "." + String(segment.dropFirst(6))
        }
        if segment.hasPrefix("id.") {
            return "#" + String(segment.dropFirst(3))
        }
        if segment.hasPrefix("tag.") {
            return String(segment.dropFirst(4))
        }
        if segment.hasPrefix("text.") {
            let content = String(segment.dropFirst(5))
            return "*:contains(\(content))"
        }
        return segment
    }

    private static func isTerminal(_ segment: String) -> Bool {
        terminalNames.contains(segment.trimmingCharacters(in: .whitespaces).lowercased())
    }

    private static func value(of element: Element, terminal: String?) -> String {
        switch terminal ?? "text" {
        case "text":
            return textLike(element)
        case "owntext":
            return element.ownText()
        case "textnodes":
            return element.textNodes().map { $0.text() }.filter { !$0.isEmpty }.joined(separator: "\n")
        case "html":
            return (try? element.html()) ?? ""
        case "all", "outerhtml":
            return (try? element.outerHtml()) ?? ""
        default:
            return (try? element.attr(terminal ?? "")) ?? ""
        }
    }

    /// 保留段落的纯文本：<br> 与块级标签转成换行，再剥离标签。
    static func textLike(_ element: Element) -> String {
        var html = (try? element.html()) ?? ""
        let replacements: [(String, String)] = [
            ("<br>", "\n"), ("<br/>", "\n"), ("<br />", "\n"),
            ("</p>", "\n\n"), ("</div>", "\n\n"), ("</li>", "\n"), ("</h1>", "\n\n"),
            ("</h2>", "\n\n"), ("</h3>", "\n\n"), ("</td>", " "), ("</tr>", "\n")
        ]
        for (pattern, replacement) in replacements {
            html = html.replacingOccurrences(of: pattern, with: replacement, options: .caseInsensitive)
        }
        html = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let decoded = (try? Entities.unescape(html)) ?? html
        let normalized = decoded
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
        var lines: [String] = []
        for line in normalized.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if lines.last?.isEmpty == false { lines.append("") }
            } else {
                lines.append(trimmed)
            }
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 正则

    private static func splitRegexReplace(_ rule: String) -> (base: String, pattern: String?, template: String) {
        guard let range = rule.range(of: "##") else { return (rule, nil, "") }
        let base = String(rule[..<range.lowerBound])
        let rest = String(rule[range.upperBound...])
        if let second = rest.range(of: "##") {
            let pattern = String(rest[..<second.lowerBound])
            var template = String(rest[second.upperBound...])
            if template.hasSuffix("###") { template = String(template.dropLast(3)) }
            return (base, pattern, template)
        }
        return (base, rest, "")
    }

    static func regexReplace(_ input: String, pattern: String, template: String) -> String {
        guard !pattern.isEmpty, let regex = try? NSRegularExpression(pattern: pattern) else { return input }
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: template)
    }

    static func regexMatches(_ pattern: String, in body: String) -> [String] {
        guard !pattern.isEmpty, let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(body.startIndex..<body.endIndex, in: body)
        return regex.matches(in: body, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let r = Range(match.range(at: 1), in: body) else {
                guard let r = Range(match.range(at: 0), in: body) else { return nil }
                return String(body[r])
            }
            return String(body[r])
        }
    }

    // MARK: - 模板与工具

    static func expand(_ rule: String, vars: [String: String], node: Any? = nil) -> String {
        guard rule.contains("{{") || rule.contains("<") else { return rule }
        var working = rule
        if let pageText = vars["page"], let page = Int(pageText) {
            working = resolvePageSets(working, page: page)
        }
        guard working.contains("{{") else { return working }
        var result = working
        guard let regex = try? NSRegularExpression(pattern: "\\{\\{([^}]*)\\}\\}") else { return working }
        let matches = regex.matches(in: working, range: NSRange(working.startIndex..<working.endIndex, in: working))
        for match in matches {
            guard let fullRange = Range(match.range, in: working),
                  let exprRange = Range(match.range(at: 1), in: working) else { continue }
            let token = String(working[fullRange])
            let expr = String(working[exprRange]).trimmingCharacters(in: .whitespaces)
            let value = inlineValue(expr, vars: vars, node: node)
            result = result.replacingOccurrences(of: token, with: value)
        }
        return result
    }

    /// Legado 的分页备选写法：`/dsyq/index<,_{{page}}>.html`
    /// 第 1 页取第一个备选（空），第 2 页取第二个，越界时停在最后一个。
    private static func resolvePageSets(_ text: String, page: Int) -> String {
        guard text.contains("<"), text.contains(",") else { return text }
        let source = text as NSString
        guard let regex = try? NSRegularExpression(pattern: "<([^<>\\s]{1,64})>") else { return text }
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: source.length))
        guard !matches.isEmpty else { return text }

        var out = ""
        var cursor = 0
        for match in matches {
            let innerRange = match.range(at: 1)
            guard innerRange.location != NSNotFound else { continue }
            let inner = source.substring(with: innerRange)
            guard inner.contains("{{") || inner.contains("_") else { continue }
            let parts = inner.components(separatedBy: ",")
            guard parts.count > 1 else { continue }
            let index = min(max(page - 1, 0), parts.count - 1)
            let prefixLength = match.range.location - cursor
            guard prefixLength >= 0 else { continue }
            out += source.substring(with: NSRange(location: cursor, length: prefixLength))
            out += parts[index]
            cursor = match.range.location + match.range.length
        }
        guard cursor > 0 else { return text }
        out += source.substring(from: cursor)
        return out
    }

    private static func inlineValue(_ expr: String, vars: [String: String], node: Any?) -> String {
        if let direct = vars[expr] { return direct }
        if let value = vars[expr.lowercased()] { return value }

        if expr.hasPrefix("$"), let node = node {
            let items = JSONPath.query(expr, root: node)
            if let first = items.first { return describe(first) }
            return ""
        }

        let pattern = #"^([A-Za-z_][A-Za-z0-9_]*)\s*([+\-*/])\s*(\d+)$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: expr, range: NSRange(expr.startIndex..<expr.endIndex, in: expr)),
           let nameRange = Range(match.range(at: 1), in: expr),
           let opRange = Range(match.range(at: 2), in: expr),
           let numRange = Range(match.range(at: 3), in: expr),
           let base = Int(vars[String(expr[nameRange])] ?? ""),
           let number = Int(expr[numRange]) {
            switch String(expr[opRange]) {
            case "+": return "\(base + number)"
            case "-": return "\(base - number)"
            case "*": return "\(base * number)"
            case "/": return number == 0 ? "\(base)" : "\(base / number)"
            default: break
            }
        }
        return ""
    }

    static func isJSRule(_ rule: String) -> Bool {
        let trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("@js:") || trimmed.hasPrefix("<js>") || trimmed.hasPrefix("js:")
    }

    static func jsBody(_ rule: String) -> String {
        var text = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("@js:") { text = String(text.dropFirst(4)) }
        else if text.hasPrefix("js:") { text = String(text.dropFirst(3)) }
        if text.hasPrefix("<js>") { text = String(text.dropFirst(4)) }
        if text.hasSuffix("</js>") { text = String(text.dropLast(5)) }
        return text
    }

    static func isXPath(_ rule: String) -> Bool {
        let trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("@xpath:") || trimmed.hasPrefix("@XPath:") || trimmed.hasPrefix("/")
    }

    static func isJSONPath(_ rule: String) -> Bool {
        let trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("@json:")
            || trimmed.hasPrefix("$.")
            || trimmed.hasPrefix("$[")
            || trimmed.hasPrefix("$..")
    }

    private static func describe(_ value: Any) -> String {
        if let element = value as? Element { return (try? element.text()) ?? "" }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        if let dict = value as? [String: Any] {
            return dict.map { "\($0.key)=\(describe($0.value))" }.joined(separator: ", ")
        }
        return "\(value)"
    }

    private static func splitLines(_ text: String) -> [String] {
        text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - JSONPath（简化实现）

    enum JSONPath {
        static func query(_ raw: String, root: Any) -> [Any] {
            var path = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if path.hasPrefix("@json:") { path = String(path.dropFirst(6)) }
            if path.hasPrefix("$") { path = String(path.dropFirst()) }

            var current: [Any] = [root]
            var index = path.startIndex
            while index < path.endIndex {
                let char = path[index]
                if char == "." {
                    let next = path.index(after: index)
                    if next < path.endIndex, path[next] == "." {
                        index = path.index(after: next)
                        let name = readName(&index, in: path)
                        current = current.flatMap { deepCollect($0, key: name) }
                    } else {
                        index = next
                        let name = readName(&index, in: path)
                        current = current.compactMap { (($0 as? [String: Any])?[name]) }
                    }
                } else if char == "[" {
                    guard let close = path[index...].firstIndex(of: "]") else { break }
                    let inner = String(path[path.index(after: index)..<close]).trimmingCharacters(in: .whitespaces)
                    index = path.index(after: close)
                    if inner == "*" {
                        current = current.flatMap { flatten($0) }
                    } else if let number = Int(inner) {
                        current = current.compactMap { value -> Any? in
                            let list = flatten(value)
                            let position = number < 0 ? list.count + number : number
                            return (position >= 0 && position < list.count) ? list[position] : nil
                        }
                    }
                } else if char.isLetter || char == "_" {
                    let name = readName(&index, in: path)
                    current = current.compactMap { (($0 as? [String: Any])?[name]) }
                } else {
                    index = path.index(after: index)
                }
            }
            return current.flatMap { flatten($0) }
        }

        private static func readName(_ index: inout String.Index, in path: String) -> String {
            var result = ""
            while index < path.endIndex, path[index] != ".", path[index] != "[" {
                result.append(path[index])
                index = path.index(after: index)
            }
            return result
        }

        private static func flatten(_ value: Any) -> [Any] {
            if let list = value as? [Any] { return list }
            return [value]
        }

        private static func deepCollect(_ value: Any, key: String) -> [Any] {
            var result: [Any] = []
            if let dict = value as? [String: Any] {
                if let found = dict[key] { result.append(contentsOf: flatten(found)) }
                for (_, child) in dict {
                    result.append(contentsOf: deepCollect(child, key: key))
                }
            } else if let list = value as? [Any] {
                for child in list {
                    result.append(contentsOf: deepCollect(child, key: key))
                }
            }
            return result
        }
    }
}