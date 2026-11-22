import Foundation

struct SyncPackage: Codable {
    var version: Int = 1
    var exportedAt: Date = Date()
    var books: [Book]
    var sources: [BookSource]
    var stats: ReadingStats
    var bookmarks: [String: [Bookmark]]
}

struct SyncResult {
    var books: Int = 0
    var sources: Int = 0
    var bookmarks: Int = 0
}

enum SyncError: LocalizedError {
    case badURL
    case http(Int)
    case decode
    case empty

    var errorDescription: String? {
        switch self {
        case .badURL: return "同步地址不合法"
        case .http(let code): return "服务器返回 \(code)，请检查账号、应用密码或路径"
        case .decode: return "备份文件格式不正确"
        case .empty: return "备份里没有可同步的数据"
        }
    }
}

enum SyncService {
    static let defaultPath = "leafreader-backup.json"

    // MARK: - 打包

    static func makePackage() -> SyncPackage {
        var marks: [String: [Bookmark]] = [:]
        for book in LibraryStore.shared.books {
            let list = LibraryStore.shared.bookmarks(for: book)
            if !list.isEmpty {
                marks[book.id.uuidString] = list
            }
        }
        return SyncPackage(
            books: LibraryStore.shared.books,
            sources: BookSourceStore.shared.sources,
            stats: StatsStore.shared.stats,
            bookmarks: marks
        )
    }

    static func encode(_ package: SyncPackage) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(package)
    }

    static func decode(_ data: Data) -> SyncPackage? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SyncPackage.self, from: data)
    }

    // MARK: - 应用

    static func apply(_ package: SyncPackage) -> SyncResult {
        var result = SyncResult()
        result.books = LibraryStore.shared.mergeBooks(package.books)
        BookSourceStore.shared.merge(package.sources)
        result.sources = package.sources.count

        for (key, incoming) in package.bookmarks {
            guard let id = UUID(uuidString: key),
                  let book = LibraryStore.shared.books.first(where: { $0.id == id }) else {
                continue
            }
            result.bookmarks += LibraryStore.shared.mergeBookmarks(incoming, for: book)
        }

        StatsStore.shared.merge(package.stats)
        return result
    }

    static func applyReport(_ data: Data, source: String) -> String {
        guard let package = decode(data) else {
            return SyncError.decode.errorDescription ?? "备份格式不正确"
        }
        let result = apply(package)
        return "\(source)合并完成：书籍 \(result.books) 本、书源 \(result.sources) 个、书签 \(result.bookmarks) 条，统计已合并"
    }

    static func localBackupURL() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("leafreader-backup.json")
        return url
    }
}

// MARK: - 坚果云 WebDAV

enum WebDAVClient {
    struct Config {
        var server: String
        var username: String
        var password: String
        var path: String

        var isConfigured: Bool {
            !server.isEmpty && !username.isEmpty && !password.isEmpty
        }
    }

    static func endpoint(for config: Config) -> URL? {
        var base = config.server.trimmingCharacters(in: .whitespacesAndNewlines)
        if !base.hasSuffix("/") { base += "/" }
        var path = config.path.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.isEmpty { path = SyncService.defaultPath }
        if path.hasPrefix("/") { path.removeFirst() }
        return URL(string: base + path)
    }

    static func upload(_ data: Data, config: Config) async throws {
        guard let url = endpoint(for: config) else { throw SyncError.badURL }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.timeoutInterval = 40
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(authHeader(config), forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SyncError.http((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    static func download(config: Config) async throws -> Data {
        guard let url = endpoint(for: config) else { throw SyncError.badURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 40
        request.setValue(authHeader(config), forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SyncError.http(-1) }
        guard (200...299).contains(http.statusCode) else { throw SyncError.http(http.statusCode) }
        guard !data.isEmpty else { throw SyncError.empty }
        return data
    }

    private static func authHeader(_ config: Config) -> String {
        let raw = "\(config.username):\(config.password)"
        let encoded = Data(raw.utf8).base64EncodedString()
        return "Basic \(encoded)"
    }
}