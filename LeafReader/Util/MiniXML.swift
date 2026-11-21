import Foundation

/// 极简 XML 树，用于解析 container.xml / OPF / nav / ncx。
/// 关闭命名空间处理，标签名统一取本地名（去掉前缀）。
final class XMLNode {
    let name: String
    var attributes: [String: String]
    var children: [XMLNode] = []
    var text: String = ""

    init(name: String, attributes: [String: String] = [:]) {
        self.name = name
        self.attributes = attributes
    }

    func attribute(_ key: String) -> String? {
        attributes[key]
    }

    func firstChild(named name: String) -> XMLNode? {
        children.first { $0.name == name }
    }

    func childElements(named name: String) -> [XMLNode] {
        children.filter { $0.name == name }
    }

    func descendants(named name: String) -> [XMLNode] {
        var result: [XMLNode] = []
        for child in children {
            if child.name == name { result.append(child) }
            result.append(contentsOf: child.descendants(named: name))
        }
        return result
    }

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 自身与所有后代节点的文本拼接（用于 <a> / <dc:title> 这类可能嵌套标签的节点）。
    var allText: String {
        let combined = text + children.map { $0.allText }.joined()
        return combined
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum MiniXML {
    static func parse(data: Data) -> XMLNode? {
        let parser = TreeParser()
        return parser.run(data: data)
    }

    static func parse(contentsOf url: URL) -> XMLNode? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return parse(data: data)
    }
}

private final class TreeParser: NSObject, XMLParserDelegate {
    private var root: XMLNode?
    private var stack: [XMLNode] = []

    func run(data: Data) -> XMLNode? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.shouldResolveExternalEntities = false
        _ = parser.parse()
        return root
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let localName = elementName.split(separator: ":").last.map(String.init) ?? elementName
        let node = XMLNode(name: localName, attributes: attributeDict)
        if let parent = stack.last {
            parent.children.append(node)
        } else if root == nil {
            root = node
        }
        stack.append(node)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if !stack.isEmpty { stack.removeLast() }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        stack.last?.text.append(string)
    }
}