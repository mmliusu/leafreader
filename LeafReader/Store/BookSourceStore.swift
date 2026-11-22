import Foundation

enum BookSourceImportError: LocalizedError {
    case invalid
    case empty

    var errorDescription: String? {
        switch self {
        case .invalid: return "不是有效的书源 JSON（需要 Legado / 阅读3.0 导出的格式）"
        case .empty: return "JSON 里没有可导入的书源"
        }
    }
}

final class BookSourceStore: ObservableObject {
    static let shared = BookSourceStore()

    @Published private(set) var sources: [BookSource] = []
    @Published var lastError: String?

    private let fm = FileManager.default
    private let fileURL: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("LeafReader", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("sources.json")
        load()
    }

    var enabledSources: [BookSource] {
        sources.filter { $0.isEnabled && $0.canSearch }
    }

    var groups: [(name: String, sources: [BookSource])] {
        let grouped = Dictionary(grouping: sources) { $0.groupName }
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
    }

    func source(id: String) -> BookSource? {
        sources.first { $0.bookSourceUrl == id }
    }

    // MARK: - 导入

    @discardableResult
    func importData(_ data: Data) -> Int {
        do {
            let parsed = try parse(data)
            var count = 0
            for var source in parsed {
                if let index = sources.firstIndex(where: { $0.bookSourceUrl == source.bookSourceUrl }) {
                    source.enabled = sources[index].enabled
                    sources[index] = source
                } else {
                    source.enabled = source.enabled ?? true
                    sources.append(source)
                }
                count += 1
            }
            sort()
            save()
            return count
        } catch let error as BookSourceImportError {
            lastError = error.errorDescription
            return 0
        } catch {
            lastError = error.localizedDescription
            return 0
        }
    }

    @discardableResult
    func importString(_ text: String) -> Int {
        guard let data = text.data(using: .utf8) else {
            lastError = BookSourceImportError.invalid.errorDescription
            return 0
        }
        return importData(data)
    }

    private func parse(_ data: Data) throws -> [BookSource] {
        let object = try? JSONSerialization.jsonObject(with: data)
        var rawList: [[String: Any]] = []
        if let list = object as? [[String: Any]] {
            rawList = list
        } else if let dict = object as? [String: Any] {
            rawList = [dict]
        } else {
            throw BookSourceImportError.invalid
        }

        var result: [BookSource] = []
        for var dict in rawList {
            guard let url = dict["bookSourceUrl"] as? String, !url.isEmpty else { continue }
            if dict["bookSourceName"] == nil {
                dict["bookSourceName"] = url
            }
            for key in ["ruleSearch", "ruleExplore", "ruleBookInfo", "ruleToc", "ruleContent"] {
                if let string = dict[key] as? String,
                   let nested = string.data(using: .utf8),
                   let parsed = try? JSONSerialization.jsonObject(with: nested) {
                    dict[key] = parsed
                }
            }
            guard let normalized = try? JSONSerialization.data(withJSONObject: dict),
                  let source = try? JSONDecoder().decode(BookSource.self, from: normalized) else {
                continue
            }
            result.append(source)
        }

        guard !result.isEmpty else { throw BookSourceImportError.empty }
        return result
    }

    // MARK: - 管理

    func setEnabled(_ enabled: Bool, for source: BookSource) {
        guard let index = sources.firstIndex(where: { $0.bookSourceUrl == source.bookSourceUrl }) else { return }
        sources[index].enabled = enabled
        save()
    }

    func remove(_ source: BookSource) {
        sources.removeAll { $0.bookSourceUrl == source.bookSourceUrl }
        save()
    }

    func removeAll() {
        sources.removeAll()
        save()
    }

    // MARK: - 持久化

    private func sort() {
        sources.sort { lhs, rhs in
            if lhs.groupName != rhs.groupName { return lhs.groupName < rhs.groupName }
            return lhs.displayName < rhs.displayName
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([BookSource].self, from: data) else {
            return
        }
        sources = decoded
        sort()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(sources) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}