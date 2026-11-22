import Foundation

struct ReadingStats: Codable {
    var bookSeconds: [String: Int] = [:]
    var dailySeconds: [String: Int] = [:]
    var lastRead: [String: Date] = [:]

    func seconds(for bookID: UUID) -> Int {
        bookSeconds[bookID.uuidString] ?? 0
    }

    func seconds(on date: Date) -> Int {
        dailySeconds[ReadingStats.dayKey(date)] ?? 0
    }

    var totalSeconds: Int {
        bookSeconds.values.reduce(0, +)
    }

    static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
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

    func add(seconds: Int, bookID: UUID, date: Date = Date()) {
        guard seconds > 0 else { return }
        let key = bookID.uuidString
        var next = stats
        next.bookSeconds[key, default: 0] += seconds
        next.dailySeconds[ReadingStats.dayKey(date), default: 0] += seconds
        next.lastRead[key] = date
        stats = next
        scheduleSave()
    }

    func seconds(for bookID: UUID) -> Int {
        stats.seconds(for: bookID)
    }

    func todaySeconds() -> Int {
        stats.seconds(on: Date())
    }

    func weekSeconds() -> Int {
        var total = 0
        let calendar = Calendar.current
        for offset in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: -offset, to: Date()) {
                total += stats.seconds(on: day)
            }
        }
        return total
    }

    func reset() {
        stats = ReadingStats()
        save()
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

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(stats) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}