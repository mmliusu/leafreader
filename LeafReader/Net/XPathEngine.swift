import Foundation
import SwiftSoup

/// 简化 XPath：支持 `//tag`、`/tag`、`*`、`[@attr]`、`[@attr='v']`、
/// `[contains(@class,'x')]`、`[n]`、结尾的 `/text()` 与 `/@attr`。
enum XPathEngine {

    enum Axis {
        case child
        case descendant
    }

    enum Predicate {
        case attrExists(String)
        case attrEquals(String, String)
        case attrContains(String, String)
        case textContains(String)
        case unsupported
    }

    struct Step {
        var axis: Axis
        var tag: String
        var predicates: [Predicate]
        var index: Int?
    }

    static func evaluate(_ expression: String, in document: Document) -> [Any] {
        var text = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("@xpath:") { text = String(text.dropFirst(7)) }
        else if text.hasPrefix("@XPath:") { text = String(text.dropFirst(7)) }

        var terminalText = false
        var terminalAttr: String?

        if text.hasSuffix("/text()") {
            terminalText = true
            text = String(text.dropLast(7))
        } else if let range = text.range(of: "/@", options: .backwards) {
            let attr = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !attr.isEmpty, !attr.contains("/") {
                terminalAttr = attr
                text = String(text[..<range.lowerBound])
            }
        }

        let steps = parseSteps(text)
        guard !steps.isEmpty else { return [] }

        var current: [Element] = [document]
        for step in steps {
            var next: [Element] = []
            for node in current {
                let pool: [Element]
                switch step.axis {
                case .descendant:
                    pool = (try? node.getAllElements()).map { Array($0) } ?? []
                case .child:
                    pool = Array(node.children())
                }
                for candidate in pool where matchesTag(candidate, step.tag) {
                    next.append(candidate)
                }
            }
            next = next.filter { candidate in
                step.predicates.allSatisfy { satisfied($0, by: candidate) }
            }
            if let index = step.index {
                let position = index > 0 ? index - 1 : next.count + index
                if position >= 0, position < next.count {
                    next = [next[position]]
                } else {
                    next = []
                }
            }
            current = next
            if current.isEmpty { break }
        }

        if terminalText {
            return current.map { (try? $0.text()) ?? "" }
        }
        if let attr = terminalAttr {
            return current.map { (try? $0.attr(attr)) ?? "" }
        }
        return current.map { $0 as Any }
    }

    // MARK: - 解析

    private static func parseSteps(_ path: String) -> [Step] {
        var steps: [Step] = []
        var index = path.startIndex

        while index < path.endIndex {
            guard path[index] == "/" else {
                index = path.index(after: index)
                continue
            }

            let axis: Axis
            let after = path.index(after: index)
            if after < path.endIndex, path[after] == "/" {
                axis = .descendant
                index = path.index(after: after)
            } else {
                axis = .child
                index = after
            }

            var tag = ""
            while index < path.endIndex, path[index] != "/", path[index] != "[" {
                tag.append(path[index])
                index = path.index(after: index)
            }

            var predicates: [Predicate] = []
            var position: Int?
            while index < path.endIndex, path[index] == "[" {
                guard let close = path[index...].firstIndex(of: "]") else { break }
                let inner = String(path[path.index(after: index)..<close])
                index = path.index(after: close)
                if let number = Int(inner.trimmingCharacters(in: .whitespaces)) {
                    position = number
                } else {
                    predicates.append(parsePredicate(inner))
                }
            }

            steps.append(
                Step(
                    axis: axis,
                    tag: tag.isEmpty ? "*" : tag,
                    predicates: predicates,
                    index: position
                )
            )
        }
        return steps
    }

    private static func parsePredicate(_ raw: String) -> Predicate {
        let text = raw.trimmingCharacters(in: .whitespaces)
        if text.lowercased().hasPrefix("contains("), text.hasSuffix(")") {
            let inner = String(text.dropFirst(9).dropLast())
            let parts = inner.split(separator: ",", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            if parts.count == 2 {
                let target = parts[0]
                let value = unquote(parts[1])
                if target == "text()" {
                    return .textContains(value)
                }
                if target.hasPrefix("@") {
                    return .attrContains(String(target.dropFirst()), value)
                }
            }
            return .unsupported
        }

        if text.hasPrefix("@") {
            let body = String(text.dropFirst())
            if let equals = body.firstIndex(of: "=") {
                let name = String(body[..<equals]).trimmingCharacters(in: .whitespaces)
                let value = unquote(String(body[body.index(after: equals)...]))
                return .attrEquals(name, value)
            }
            return .attrExists(body)
        }

        return .unsupported
    }

    private static func unquote(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("'") || value.hasPrefix("\"") { value.removeFirst() }
        if value.hasSuffix("'") || value.hasSuffix("\"") { value.removeLast() }
        return value
    }

    // MARK: - 匹配

    private static func matchesTag(_ element: Element, _ tag: String) -> Bool {
        if tag == "*" { return true }
        return element.tagName().lowercased() == tag.lowercased()
    }

    private static func satisfied(_ predicate: Predicate, by element: Element) -> Bool {
        switch predicate {
        case .attrExists(let name):
            return !((try? element.attr(name)) ?? "").isEmpty
        case .attrEquals(let name, let value):
            return (try? element.attr(name)) == value
        case .attrContains(let name, let value):
            return ((try? element.attr(name)) ?? "").contains(value)
        case .textContains(let value):
            return ((try? element.text()) ?? "").contains(value)
        case .unsupported:
            return true
        }
    }
}