import Foundation
import ZIPFoundation

struct EpubMetadata {
    var title: String?
    var author: String?
    var coverEntryPath: String?
}

struct EpubSection {
    let title: String
    let url: URL
}

struct EpubVolume {
    let rootURL: URL
    let sections: [EpubSection]
}

enum EpubError: LocalizedError {
    case invalidPackage
    case encrypted
    case emptySpine

    var errorDescription: String? {
        switch self {
        case .invalidPackage: return "EPUB 结构不完整或已损坏。"
        case .encrypted: return "这本 EPUB 带 DRM 加密，无法打开。"
        case .emptySpine: return "EPUB 中没有可阅读的章节。"
        }
    }
}

private struct OpfItem {
    let href: String
    let mediaType: String
    let properties: String
}

enum EpubParser {

    // MARK: - 元数据

    static func readMetadata(archiveAt archiveURL: URL) -> EpubMetadata? {
        guard let archive = try? Archive(url: archiveURL, accessMode: .read),
              let opfRelative = opfPath(in: archive),
              let opfData = data(forPath: opfRelative, in: archive),
              let root = MiniXML.parse(data: opfData) else {
            return nil
        }
        let opfDir = directoryPath(of: opfRelative)
        var metadata = EpubMetadata()

        if let node = root.descendants(named: "title").first {
            let value = node.allText
            if !value.isEmpty { metadata.title = value }
        }
        if let node = root.descendants(named: "creator").first {
            let value = node.allText
            if !value.isEmpty { metadata.author = value }
        }

        let items = root.descendants(named: "item")
        var coverHref: String?

        if let coverItem = items.first(where: { item in
            let properties = item.attribute("properties") ?? ""
            return properties.split(separator: " ").map(String.init).contains("cover-image")
        }) {
            coverHref = coverItem.attribute("href")
        }

        if coverHref == nil,
           let meta = root.descendants(named: "meta").first(where: { $0.attribute("name") == "cover" }),
           let coverID = meta.attribute("content"),
           let item = items.first(where: { $0.attribute("id") == coverID }) {
            coverHref = item.attribute("href")
        }

        if let href = coverHref, !href.isEmpty {
            metadata.coverEntryPath = resolve(path: href, relativeTo: opfDir)
        }
        return metadata
    }

    static func extractEntry(_ path: String, fromArchiveAt archiveURL: URL, to destination: URL) -> Bool {
        guard let archive = try? Archive(url: archiveURL, accessMode: .read),
              let data = data(forPath: path, in: archive) else {
            return false
        }
        do {
            try data.write(to: destination, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    // MARK: - 解包与章节

    static func readVolume(archiveAt archiveURL: URL, rootURL: URL) throws -> EpubVolume {
        let fm = FileManager.default
        let containerPath = rootURL.appendingPathComponent("META-INF/container.xml").path

        if !fm.fileExists(atPath: containerPath) {
            try? fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
            do {
                try fm.unzipItem(at: archiveURL, to: rootURL)
            } catch {
                throw EpubError.invalidPackage
            }
        }

        if fm.fileExists(atPath: rootURL.appendingPathComponent("META-INF/encryption.xml").path) {
            throw EpubError.encrypted
        }

        guard let opfRelative = opfPath(atRoot: rootURL) else {
            throw EpubError.invalidPackage
        }
        let opfDir = directoryPath(of: opfRelative)
        let opfURL = rootURL.appendingPathComponent(opfRelative)

        guard let root = MiniXML.parse(contentsOf: opfURL) else {
            throw EpubError.invalidPackage
        }

        var manifest: [String: OpfItem] = [:]
        for item in root.descendants(named: "item") {
            guard let id = item.attribute("id"), let href = item.attribute("href") else { continue }
            manifest[id] = OpfItem(
                href: href,
                mediaType: item.attribute("media-type") ?? "",
                properties: item.attribute("properties") ?? ""
            )
        }

        var spineItems: [OpfItem] = []
        for itemref in root.descendants(named: "itemref") {
            guard let idref = itemref.attribute("idref") else { continue }
            if itemref.attribute("linear")?.lowercased() == "no" { continue }
            guard let item = manifest[idref] else { continue }
            spineItems.append(item)
        }
        guard !spineItems.isEmpty else { throw EpubError.emptySpine }

        var titles: [String: String] = [:]

        // EPUB3: nav 文档
        if let navItem = manifest.values.first(where: { item in
            item.properties.split(separator: " ").map(String.init).contains("nav")
        }) {
            let navRelative = resolve(path: navItem.href, relativeTo: opfDir)
            let navURL = rootURL.appendingPathComponent(navRelative)
            if let navRoot = MiniXML.parse(contentsOf: navURL) {
                collectNavTitles(from: navRoot, baseDirectory: directoryPath(of: navRelative), into: &titles)
            }
        }

        // EPUB2: toc.ncx
        if titles.isEmpty,
           let ncx = manifest.values.first(where: { $0.mediaType.contains("dtbncx") || $0.href.lowercased().hasSuffix(".ncx") }) {
            let ncxRelative = resolve(path: ncx.href, relativeTo: opfDir)
            let ncxURL = rootURL.appendingPathComponent(ncxRelative)
            if let ncxRoot = MiniXML.parse(contentsOf: ncxURL) {
                collectNcxTitles(from: ncxRoot, baseDirectory: directoryPath(of: ncxRelative), into: &titles)
            }
        }

        var sections: [EpubSection] = []
        for (index, item) in spineItems.enumerated() {
            let relative = resolve(path: item.href, relativeTo: opfDir)
            let url = rootURL.appendingPathComponent(relative)
            let key = stripFragment(relative)
            let title = titles[key] ?? "第 \(index + 1) 章"
            sections.append(EpubSection(title: title, url: url))
        }

        return EpubVolume(rootURL: rootURL, sections: sections)
    }

    // MARK: - 目录解析

    private static func collectNavTitles(from root: XMLNode, baseDirectory: String, into titles: inout [String: String]) {
        let navs = root.descendants(named: "nav")
        let toc = navs.first { nav in
            (nav.attribute("epub:type") ?? nav.attribute("type") ?? "").contains("toc")
        } ?? navs.first

        guard let container = toc else { return }

        for link in container.descendants(named: "a") {
            guard let href = link.attribute("href"), !href.isEmpty else { continue }
            let text = link.allText
            guard !text.isEmpty else { continue }
            let key = stripFragment(resolve(path: href, relativeTo: baseDirectory))
            if titles[key] == nil {
                titles[key] = text
            }
        }
    }

    private static func collectNcxTitles(from root: XMLNode, baseDirectory: String, into titles: inout [String: String]) {
        for point in root.descendants(named: "navPoint") {
            guard let content = point.firstChild(named: "content"),
                  let src = content.attribute("src"), !src.isEmpty else { continue }
            let label = point.firstChild(named: "navLabel")?.firstChild(named: "text")?.allText
                ?? point.descendants(named: "text").first?.allText
                ?? ""
            guard !label.isEmpty else { continue }
            let key = stripFragment(resolve(path: src, relativeTo: baseDirectory))
            if titles[key] == nil {
                titles[key] = label
            }
        }
    }

    // MARK: - ZIP 辅助

    private static func opfPath(in archive: Archive) -> String? {
        guard let data = data(forPath: "META-INF/container.xml", in: archive),
              let root = MiniXML.parse(data: data),
              let rootfile = root.descendants(named: "rootfile").first,
              let path = rootfile.attribute("full-path") else {
            return nil
        }
        return path
    }

    private static func opfPath(atRoot rootURL: URL) -> String? {
        guard let root = MiniXML.parse(contentsOf: rootURL.appendingPathComponent("META-INF/container.xml")),
              let rootfile = root.descendants(named: "rootfile").first,
              let path = rootfile.attribute("full-path") else {
            return nil
        }
        return path
    }

    private static func data(forPath path: String, in archive: Archive) -> Data? {
        let candidates = [path, path.removingPercentEncoding].compactMap { $0 }
        for candidate in candidates {
            guard let entry = archive[candidate] else { continue }
            var buffer = Data()
            do {
                _ = try archive.extract(entry) { chunk in
                    buffer.append(chunk)
                }
                return buffer
            } catch {
                continue
            }
        }
        return nil
    }

    private static func directoryPath(of path: String) -> String {
        guard let index = path.lastIndex(of: "/") else { return "" }
        return String(path[path.startIndex..<index])
    }

    private static func stripFragment(_ path: String) -> String {
        guard let index = path.firstIndex(of: "#") else { return path }
        return String(path[path.startIndex..<index])
    }

    private static func resolve(path: String, relativeTo base: String) -> String {
        let decoded = path.removingPercentEncoding ?? path
        let combined = base.isEmpty ? decoded : base + "/" + decoded
        var parts: [String] = []
        for component in combined.split(separator: "/", omittingEmptySubsequences: true) {
            if component == "." { continue }
            if component == ".." {
                if !parts.isEmpty { parts.removeLast() }
                continue
            }
            parts.append(String(component))
        }
        return parts.joined(separator: "/")
    }
}