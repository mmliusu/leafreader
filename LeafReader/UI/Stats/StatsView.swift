import SwiftUI

enum StatsPeriod: String, CaseIterable, Identifiable {
    case total
    case day
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .total: return "总"
        case .day: return "日"
        case .week: return "周"
        case .month: return "月"
        case .year: return "年"
        }
    }
}

enum StatsDefaults {
    static func modules(_ period: StatsPeriod) -> [String] {
        switch period {
        case .total:
            return ["total.companion", "total.overview", "total.recent9", "total.heartbeat", "total.recent30", "total.longest"]
        case .day:
            return ["day.overview", "day.efficiency", "day.habit", "day.highlights", "day.period", "day.hourly", "day.ranking"]
        case .week:
            return ["week.overview", "week.time", "week.favorite", "week.period", "week.behavior", "week.preference", "week.persistence", "week.ranking"]
        case .month:
            return ["month.overview", "month.calendar", "month.duration", "month.time", "month.heatmap", "month.behavior", "month.preference", "month.persistence", "month.ranking"]
        case .year:
            return ["year.overview", "year.heatmap", "year.habit", "year.monthFavorite", "year.period", "year.records", "year.ranking"]
        }
    }

    static func title(_ id: String) -> String {
        let map: [String: String] = [
            "total.companion": "陪伴天数",
            "total.overview": "总览指标",
            "total.recent9": "最近 9 天",
            "total.heartbeat": "阅读心跳",
            "total.recent30": "最近 30 天热力",
            "total.longest": "阅读时间最长的文件",
            "day.overview": "当日阅读总览",
            "day.efficiency": "效率指标",
            "day.habit": "阅读习惯分析",
            "day.highlights": "当日之最",
            "day.period": "时间分布",
            "day.hourly": "时段阅读详情",
            "day.ranking": "阅读排行",
            "week.overview": "周度总览",
            "week.time": "时间分析",
            "week.favorite": "本周最爱",
            "week.period": "阅读时间分布",
            "week.behavior": "行为分析",
            "week.preference": "书籍偏好",
            "week.persistence": "毅力成就",
            "week.ranking": "阅读排行",
            "month.overview": "月度总览",
            "month.calendar": "月历·活跃日历",
            "month.duration": "阅读时长月历",
            "month.time": "时间分析",
            "month.heatmap": "活跃热力图",
            "month.behavior": "行为分析",
            "month.preference": "书籍偏好",
            "month.persistence": "毅力成就",
            "month.ranking": "阅读排行",
            "year.overview": "年度总览",
            "year.heatmap": "年度热力图",
            "year.habit": "阅读习惯",
            "year.monthFavorite": "月度最爱",
            "year.period": "阅读时间分布",
            "year.records": "年度记录",
            "year.ranking": "阅读排行"
        ]
        return map[id] ?? id
    }
}

struct StatsView: View {
    var standalone: Bool = false

    @EnvironmentObject private var library: LibraryStore
    @ObservedObject private var store = StatsStore.shared
    @Environment(\.dismiss) private var dismiss

    @AppStorage("stats.modules.total") private var totalConfig = ""
    @AppStorage("stats.modules.day") private var dayConfig = ""
    @AppStorage("stats.modules.week") private var weekConfig = ""
    @AppStorage("stats.modules.month") private var monthConfig = ""
    @AppStorage("stats.modules.year") private var yearConfig = ""

    @State private var period: StatsPeriod = .total
    @State private var anchor = Date()
    @State private var showSettings = false
    @State private var showShare = false
    @State private var shareImage: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                StatsStyle.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        segment
                        if period != .total {
                            dateNavigator
                        }
                        ForEach(modules, id: \.self) { id in
                            moduleView(id)
                        }
                        footer
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) {
                StatsModuleEditor(
                    all: StatsDefaults.modules(period),
                    visible: modules
                ) { newValue in
                    saveModules(newValue)
                }
            }
            .sheet(isPresented: $showShare) {
                if let image = shareImage {
                    ShareImageView(image: image)
                }
            }
        }
    }

    // MARK: - 顶部

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("统计")
                .font(AppFont.size(30))
                .foregroundStyle(StatsStyle.accent)

            Spacer()

            if period == .total {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 17))
                        .foregroundStyle(StatsStyle.accent)
                }
            } else {
                Button {
                    share()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "square.and.arrow.up")
                        Text("分享\(period.title)统计")
                    }
                    .font(AppFont.caption2)
                    .foregroundStyle(StatsStyle.accent)
                }

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17))
                        .foregroundStyle(StatsStyle.accent)
                }
            }

            if !standalone {
                Button {
                    dismiss()
                } label: {
                    Text("完成")
                        .font(AppFont.footnote)
                        .foregroundStyle(StatsStyle.secondary)
                }
            }
        }
        .padding(.top, 8)
    }

    private var segment: some View {
        HStack(spacing: 4) {
            ForEach(StatsPeriod.allCases) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        period = item
                    }
                } label: {
                    Text(item.title)
                        .font(AppFont.footnote)
                        .foregroundStyle(period == item ? Color.white : StatsStyle.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Group {
                                if period == item {
                                    Capsule().fill(StatsStyle.accentLight)
                                } else {
                                    Color.clear
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(StatsStyle.card)
        .clipShape(Capsule())
    }

    private var dateNavigator: some View {
        HStack(spacing: 12) {
            Button {
                move(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(StatsStyle.accent)
                    .frame(width: 30, height: 30)
                    .background(StatsStyle.inner)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()
            Text(anchorText)
                .font(AppFont.footnote)
                .foregroundStyle(StatsStyle.text)
            Spacer()

            Button {
                move(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(canMoveForward ? StatsStyle.accent : StatsStyle.heatEmpty)
                    .frame(width: 30, height: 30)
                    .background(StatsStyle.inner)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canMoveForward)
        }
        .padding(.vertical, 2)
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("数据只保存在本机")
                .font(AppFont.caption2)
                .foregroundStyle(StatsStyle.secondary)
            Text("在「备份与恢复」里可以导出或在设备间同步")
                .font(AppFont.caption2)
                .foregroundStyle(StatsStyle.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    // MARK: - 周期

    private var range: DateInterval {
        StatsRange.range(period: period, anchor: anchor)
    }

    private var anchorText: String {
        StatsRange.label(period: period, anchor: anchor)
    }

    private var canMoveForward: Bool {
        StatsRange.range(period: period, anchor: anchor).end > Date()
    }

    private func move(_ step: Int) {
        anchor = StatsRange.shift(period: period, anchor: anchor, step: step)
    }

    // MARK: - 模块

    private var modules: [String] {
        let raw = configRaw
        if let data = raw.data(using: .utf8),
           let list = try? JSONDecoder().decode([String].self, from: data),
           !list.isEmpty {
            return list
        }
        return StatsDefaults.modules(period)
    }

    private var configRaw: String {
        switch period {
        case .total: return totalConfig
        case .day: return dayConfig
        case .week: return weekConfig
        case .month: return monthConfig
        case .year: return yearConfig
        }
    }

    private func saveModules(_ value: [String]) {
        guard let data = try? JSONEncoder().encode(value),
              let text = String(data: data, encoding: .utf8) else { return }
        switch period {
        case .total: totalConfig = text
        case .day: dayConfig = text
        case .week: weekConfig = text
        case .month: monthConfig = text
        case .year: yearConfig = text
        }
    }

    @ViewBuilder
    private func moduleView(_ id: String) -> some View {
        StatsModuleView(id: id, context: context)
    }

    private var context: StatsContext {
        StatsContext(
            period: period,
            anchor: anchor,
            range: range,
            books: library.books,
            stats: store.stats
        )
    }

    // MARK: - 分享

    private func share() {
        let ctx = context
        let card = VStack(alignment: .leading, spacing: 12) {
            Text("\(ctx.period.title)阅读统计")
                .font(AppFont.headline)
                .foregroundStyle(StatsStyle.text)
            Text(StatsRange.label(period: ctx.period, anchor: ctx.anchor))
                .font(AppFont.caption2)
                .foregroundStyle(StatsStyle.secondary)
            Text(StatsStore.formatted(ctx.seconds))
                .font(AppFont.size(30))
                .foregroundStyle(StatsStyle.accent)
            HStack(spacing: 20) {
                shareItem("\(ctx.books)", "书籍")
                shareItem("\(ctx.opens)", "打开")
                shareItem("\(ctx.turns)", "翻页")
                shareItem(StatsStore.formattedChars(ctx.chars), "字数")
            }
            Text("墨阅 · 阅读统计")
                .font(AppFont.caption2)
                .foregroundStyle(StatsStyle.secondary)
        }
        .padding(20)
        .frame(width: 340, alignment: .leading)
        .background(StatsStyle.card)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        shareImage = renderer.uiImage
        showShare = shareImage != nil
    }

    private func shareItem(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppFont.size(15))
                .foregroundStyle(StatsStyle.text)
            Text(label)
                .font(AppFont.caption2)
                .foregroundStyle(StatsStyle.secondary)
        }
    }
}

// MARK: - 周期计算

enum StatsRange {
    static func range(period: StatsPeriod, anchor: Date) -> DateInterval {
        let calendar = Calendar.current
        switch period {
        case .total:
            return DateInterval(start: .distantPast, end: Date().addingTimeInterval(1))
        case .day:
            let start = calendar.startOfDay(for: anchor)
            return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: start) ?? start)
        case .week:
            let weekday = calendar.component(.weekday, from: anchor)
            let offset = (weekday + 5) % 7
            let start = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: anchor)) ?? anchor
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .month:
            let comps = calendar.dateComponents([.year, .month], from: anchor)
            let start = calendar.date(from: comps) ?? anchor
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .year:
            let comps = calendar.dateComponents([.year], from: anchor)
            let start = calendar.date(from: comps) ?? anchor
            let end = calendar.date(byAdding: .year, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        }
    }

    static func shift(period: StatsPeriod, anchor: Date, step: Int) -> Date {
        let calendar = Calendar.current
        switch period {
        case .total: return anchor
        case .day: return calendar.date(byAdding: .day, value: step, to: anchor) ?? anchor
        case .week: return calendar.date(byAdding: .day, value: step * 7, to: anchor) ?? anchor
        case .month: return calendar.date(byAdding: .month, value: step, to: anchor) ?? anchor
        case .year: return calendar.date(byAdding: .year, value: step, to: anchor) ?? anchor
        }
    }

    static func label(period: StatsPeriod, anchor: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        switch period {
        case .total:
            return "全部时间"
        case .day:
            formatter.dateFormat = "yyyy年M月d日"
            return formatter.string(from: anchor)
        case .week:
            let range = range(period: .week, anchor: anchor)
            let start = range.start
            let end = range.end.addingTimeInterval(-1)
            formatter.dateFormat = "M月d日"
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        case .month:
            formatter.dateFormat = "yyyy年M月"
            return formatter.string(from: anchor)
        case .year:
            formatter.dateFormat = "yyyy年"
            return formatter.string(from: anchor)
        }
    }
}

// MARK: - 数据上下文

struct StatsContext {
    let period: StatsPeriod
    let anchor: Date
    let range: DateInterval
    let books: [Book]
    let stats: ReadingStats

    var hasData: Bool { seconds > 0 }

    var seconds: Int {
        period == .total ? stats.totalSeconds : stats.seconds(in: range)
    }

    var turns: Int {
        period == .total ? stats.totalPageTurns : stats.pageTurns(in: range)
    }

    var chars: Int {
        period == .total ? stats.totalChars : stats.chars(in: range)
    }

    var opens: Int {
        period == .total ? stats.totalOpens : stats.opens(in: range)
    }

    var readingBooks: Int {
        stats.booksRead(in: period == .total ? nil : range)
    }

    var finishedBooks: Int {
        books.filter { $0.progress >= 0.995 }.count
    }

    var inProgressBooks: Int {
        books.filter { $0.progress > 0 && $0.progress < 0.995 }.count
    }

    var days: Int {
        max(1, Calendar.current.dateComponents([.day], from: range.start, to: min(range.end, Date())).day ?? 1)
    }

    var dailyAverage: Int { seconds / days }

    var ranking: [(book: Book?, seconds: Int)] {
        Array(stats.bookRanking(in: period == .total ? nil : range).prefix(period == .year ? 999 : 99)).map { item in
            (books.first { $0.id.uuidString == item.id }, item.seconds)
        }
    }

    var openRanking: [(book: Book?, opens: Int)] {
        Array(stats.bookOpenRanking(in: period == .total ? nil : range).prefix(5)).map { item in
            (books.first { $0.id.uuidString == item.id }, item.opens)
        }
    }

    var hours: [Int] { stats.hourlyDistribution() }

    func segments(_ title: String, icon: String) -> (title: String, seconds: Int, icon: String) {
        (title, 0, icon)
    }

    var periodShares: [(title: String, seconds: Int, icon: String)] {
        let hours = self.hours
        let buckets: [(String, Int, Int, String)] = [
            ("凌晨 0-6", 0, 6, "moon.stars"),
            ("上午 6-12", 6, 12, "sunrise"),
            ("下午 12-18", 12, 18, "sun.max"),
            ("晚上 18-24", 18, 24, "moon")
        ]
        return buckets.map { item in
            (item.0, (item.1..<item.2).reduce(0) { $0 + hours[$1] }, item.3)
        }
    }

    func bookTitle(_ id: String) -> String {
        books.first { $0.id.uuidString == id }?.title ?? "未知书籍"
    }
}