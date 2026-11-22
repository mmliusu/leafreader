import Foundation

struct ReadingStats: Codable {
    var bookSeconds: [String: Int] = [:]
    var dailySeconds: [String: Int] = [:]
    var lastRead: [String: Date] = [:]

    var bookPageTurns: [String: Int] = [:]
    var dailyPageTurns: [String: Int] = [:]
    var bookChars: [String: Int] = [:]
    var dailyChars: [String: Int] = [:]

    private enum CodingKeys: String, CodingKey {
        case bookSeconds, dailySeconds, lastRead
        case bookPageTurns, dailyPageTurns, bookChars, dailyChars
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bookSeconds = try c.decodeIfPresent([String: Int].self, forKey: .bookSeconds) ?? [:]
        dailySeconds = try c.decodeIfPresent([String: Int].self, forKey: .dailySeconds) ?? [:]
        lastRead = try c.decodeIfPresent([String: Date].self, forKey: .lastRead) ?? [:]
        bookPageTurns = try c.decodeIfPresent([String: Int].self, forKey: .bookPageTurns) ?? [:]
        dailyPageTurns = try c.decodeIfPresent([String: Int].self, forKey: .dailyPageTurns) ?? [:]
        bookChars = try c.decodeIfPresent([String: Int].self, forKey: .bookChars) ?? [:]
        dailyChars = try c.decodeIfPresent([String: Int].self, forKey: .dailyChars) ?? [:]
    }

    // MARK: - 读取

    func seconds(for bookID: UUID) -> Int {
        bookSeconds[bookID.uuidString] ?? 0
    }

    func pageTurns(for bookID: UUID) -> Int {
        bookPageTurns[bookID.uuidString] ?? 0
    }

    func chars(for bookID: UUID) -> Int {
        bookChars[bookID.uuidString] ?? 0
    }

    func seconds(on date: Date) -> Int {
        dailySeconds[ReadingStats.dayKey(date)] ?? 0
    }

    func pageTurns(on date: Date) -> Int {
        dailyPageTurns[ReadingStats.dayKey(date)] ?? 0
    }

    func chars(on date: Date) -> Int {
        dailyChars[ReadingStats.dayKey(date)] ?? 0
    }

    var totalSeconds: Int { bookSeconds.values.reduce(0, +) }
    var totalPageTurns: Int { bookPageTurns.values.reduce(0, +) }
    var totalChars: Int { bookChars.values.reduce(0, +) }

    func seconds(in range: DateInterval) -> Int {
        sum(dailySeconds, in: range)
    }

    func pageTurns(in range: DateInterval) -> Int {
        sum(dailyPageTurns, in: range)
    }

    func chars(in range: DateInterval) -> Int {
        sum(dailyChars, in: range)
    }

    private func sum(_ source: [String: Int], in range: DateInterval) -> Int {
        var total = 0
        for (key, value) in source {
            guard let date = ReadingStats.date(fromKey: key) else { continue }
            if range.contains(date) { total += value }
        }
        return total
    }

    // MARK: - 日期工具

    static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    static func date(fromKey key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: key)
    }
}

struct DailyStatPoint: Identifiable {
    var id: Date { date }
    var date: Date
    var seconds: Int
    var pageTurns: Int
    var chars: Int

    var minutes: Double { Double(seconds) / 60.0 }
}

final class StatsStore: ObservableObject {
    static let shared = StatsStore()

    @Published private(set) var stats = ReadingStats()
    private let fileURL: URL
    private var saveTimer: Timer?

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("LeafReader", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("stats.json")
        load()
    }

    // MARK: - 记录

    func add(seconds: Int, pageTurns: Int, chars: Int, bookID: UUID, date: Date = Date()) {
        guard seconds > 0 || pageTurns > 0 || chars > 0 else { return }
        let key = bookID.uuidString
        let day = ReadingStats.dayKey(date)
        var next = stats
        if seconds > 0 {
            next.bookSeconds[key, default: 0] += seconds
            next.dailySeconds[day, default: 0] += seconds
            next.lastRead[key] = date
        }
        if pageTurns > 0 {
            next.bookPageTurns[key, default: 0] += pageTurns
            next.dailyPageTurns[day, default: 0] += pageTurns
        }
        if chars > 0 {
            next.bookChars[key, default: 0] += chars
            next.dailyChars[day, default: 0] += chars
        }
        stats = next
        scheduleSave()
    }

    /// 同步导入时整体替换
    func replace(_ value: ReadingStats) {
        stats = value
        save()
    }

    func merge(_ other: ReadingStats) {
        var next = stats
        for (key, value) in other.bookSeconds { next.bookSeconds[key, default: 0] += value }
        for (key, value) in other.dailySeconds { next.dailySeconds[key, default: 0] += value }
        for (key, value) in other.bookPageTurns { next.bookPageTurns[key, default: 0] += value }
        for (key, value) in other.dailyPageTurns { next.dailyPageTurns[key, default: 0] += value }
        for (key, value) in other.bookChars { next.bookChars[key, default: 0] += value }
        for (key, value) in other.dailyChars { next.dailyChars[key, default: 0] += value }
        for (key, value) in other.lastRead {
            if let existing = next.lastRead[key] {
                next.lastRead[key] = max(existing, value)
            } else {
                next.lastRead[key] = value
            }
        }
        stats = next
        save()
    }

    func seconds(for bookID: UUID) -> Int { stats.seconds(for: bookID) }
    func pageTurns(for bookID: UUID) -> Int { stats.pageTurns(for: bookID) }
    func chars(for bookID: UUID) -> Int { stats.chars(for: bookID) }

    func todaySeconds() -> Int { stats.seconds(on: Date()) }
    func weekSeconds() -> Int { stats.seconds(in: Self.weekRange()) }
    func monthSeconds() -> Int { stats.seconds(in: Self.monthRange()) }
    func yearSeconds() -> Int { stats.seconds(in: Self.yearRange()) }

    func reset() {
        stats = ReadingStats()
        save()
    }

    // MARK: - 区间

    static func weekRange() -> DateInterval {
        let calendar = Calendar.current
        let now = Date()
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        return DateInterval(start: start, end: now.addingTimeInterval(1))
    }

    static func monthRange() -> DateInterval {
        let calendar = Calendar.current
        let now = Date()
        let comps = calendar.dateComponents([.year, .month], from: now)
        let start = calendar.date(from: comps) ?? now
        return DateInterval(start: start, end: now.addingTimeInterval(1))
    }

    static func yearRange() -> DateInterval {
        let calendar = Calendar.current
        let now = Date()
        let comps = calendar.dateComponents([.year], from: now)
        let start = calendar.date(from: comps) ?? now
        return DateInterval(start: start, end: now.addingTimeInterval(1))
    }

    /// 最近 n 天（含今天）的每日数据，按日期升序
    func dailySeries(days: Int) -> [DailyStatPoint] {
        let calendar = Calendar.current
        var result: [DailyStatPoint] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            result.append(
                DailyStatPoint(
                    date: calendar.startOfDay(for: day),
                    seconds: stats.seconds(on: day),
                    pageTurns: stats.pageTurns(on: day),
                    chars: stats.chars(on: day)
                )
            )
        }
        return result
    }

    // MARK: - 格式化

    static func formatted(_ seconds: Int) -> String {
        guard seconds > 0 else { return "0 分钟" }
        if seconds < 60 { return "\(seconds) 秒" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) 分钟" }
        let hours = minutes / 60
        let remain = minutes % 60
        return remain == 0 ? "\(hours) 小时" : "\(hours) 小时 \(remain) 分"
    }

    static func formattedChars(_ chars: Int) -> String {
        if chars < 10000 { return "\(chars) 字" }
        return String(format: "%.1f 万字", Double(chars) / 10000)
    }

    // MARK: - 持久化

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode(ReadingStats.self, from: data) {
            stats = decoded
        }
    }

    private func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            self?.save()
        }
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(stats) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}