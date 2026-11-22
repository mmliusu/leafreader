import SwiftUI
import Charts

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

    var overviewTitle: String {
        switch self {
        case .total: return "累计阅读总览"
        case .day: return "当日阅读总览"
        case .week: return "本周阅读总览"
        case .month: return "本月阅读总览"
        case .year: return "今年阅读总览"
        }
    }
}

struct StatsView: View {
    var standalone: Bool = false

    @EnvironmentObject private var library: LibraryStore
    @ObservedObject private var store = StatsStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var period: StatsPeriod = .total
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("范围", selection: $period) {
                        ForEach(StatsPeriod.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    overviewCard
                    efficiencyGrid
                    periodCard
                    rankingCard

                    if period == .total {
                        barChart(title: "最近 7 天阅读时长", points: store.dailySeries(days: 7), height: 140)
                        barChart(title: "最近 30 天阅读时长", points: store.dailySeries(days: 30), height: 160)
                        heatmapCard()
                    }

                    if !standalone {
                        Button(role: .destructive) {
                            showResetConfirm = true
                        } label: {
                            Label("清空阅读统计", systemImage: "trash")
                                .font(AppFont.footnote)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(16)
                .padding(.bottom, 20)
            }
            .navigationTitle("统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !standalone {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") { dismiss() }
                    }
                }
            }
            .confirmationDialog("清空全部阅读统计？", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("清空", role: .destructive) { store.reset() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("时长、翻页、字数、打开次数都会被删除，书架和书源不受影响。")
            }
        }
    }

    // MARK: - 数据

    private var range: DateInterval? {
        switch period {
        case .total:
            return nil
        case .day:
            return DateInterval(
                start: Calendar.current.startOfDay(for: Date()),
                end: Date().addingTimeInterval(1)
            )
        case .week:
            return StatsStore.weekRange()
        case .month:
            return StatsStore.monthRange()
        case .year:
            return StatsStore.yearRange()
        }
    }

    private var currentSeconds: Int {
        guard let range = range else { return store.stats.totalSeconds }
        return store.stats.seconds(in: range)
    }

    private var currentTurns: Int {
        guard let range = range else { return store.stats.totalPageTurns }
        return store.stats.pageTurns(in: range)
    }

    private var currentChars: Int {
        guard let range = range else { return store.stats.totalChars }
        return store.stats.chars(in: range)
    }

    private var currentOpens: Int {
        guard let range = range else { return store.stats.totalOpens }
        return store.stats.opens(in: range)
    }

    private var currentBooks: Int {
        store.stats.booksRead(in: range)
    }

    // MARK: - 概览

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(period.overviewTitle)
                    .font(AppFont.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "book")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#2E626B"))
            }

            Text(StatsStore.formatted(currentSeconds))
                .font(AppFont.size(30))
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            HStack(spacing: 0) {
                overviewItem("\(currentBooks)", "书籍")
                overviewItem("\(currentOpens)", "打开")
                overviewItem("\(currentTurns)", "翻页")
                overviewItem(StatsStore.formattedChars(currentChars), "字数")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#2E626B").opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func overviewItem(_ value: String, _ title: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(AppFont.size(15).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(AppFont.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 效率

    private var efficiencyGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("效率指标")
                .font(AppFont.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                efficiencyCard("平均阅读", "每本书", averageText, "clock", Color(hex: "#3D8B7A"))
                efficiencyCard("翻页速度", "平均每页", speedText, "gauge", Color(hex: "#C07A3A"))
                efficiencyCard("阅读效率", "每分钟翻页", efficiencyText, "speedometer", Color(hex: "#3A6EA5"))
                efficiencyCard("使用频次", "每本书打开", frequencyText, "arrow.triangle.2.circlepath", Color(hex: "#7B5EA7"))
            }
        }
    }

    private func efficiencyCard(
        _ title: String,
        _ subtitle: String,
        _ value: String,
        _ symbol: String,
        _ tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 12))
                    .foregroundStyle(tint)
                Text(title)
                    .font(AppFont.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(AppFont.size(18))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(subtitle)
                .font(AppFont.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var averageText: String {
        guard currentBooks > 0 else { return "0 分钟" }
        let minutes = Double(currentSeconds) / 60.0 / Double(currentBooks)
        return String(format: "%.1f 分钟", minutes)
    }

    private var speedText: String {
        guard currentTurns > 0 else { return "-- 秒/页" }
        return String(format: "%.1f 秒/页", Double(currentSeconds) / Double(currentTurns))
    }

    private var efficiencyText: String {
        guard currentSeconds > 0 else { return "-- 页/分" }
        let minutes = Double(currentSeconds) / 60.0
        return String(format: "%.1f 页/分", Double(currentTurns) / max(minutes, 0.001))
    }

    private var frequencyText: String {
        guard currentBooks > 0 else { return "0 次/书" }
        return String(format: "%.1f 次/书", Double(currentOpens) / Double(currentBooks))
    }

    // MARK: - 时段分布

    private var periodShares: [(title: String, seconds: Int)] {
        let hours = store.stats.hourlyDistribution()
        let segments: [(String, Int, Int)] = [
            ("凌晨 0-6", 0, 6),
            ("上午 6-12", 6, 12),
            ("下午 12-18", 12, 18),
            ("晚上 18-24", 18, 24)
        ]
        return segments.map { item in
            let value = (item.1..<item.2).reduce(0) { $0 + hours[$1] }
            return (item.0, value)
        }
    }

    private var periodCard: some View {
        let shares = periodShares
        let total = shares.reduce(0) { $0 + $1.seconds }
        let top = shares.max { $0.seconds < $1.seconds }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("时间分布")
                    .font(AppFont.headline)
                Spacer()
                Text("累计")
                    .font(AppFont.caption2)
                    .foregroundStyle(.secondary)
            }

            if total <= 0 {
                Text("还没有足够的阅读记录")
                    .font(AppFont.footnote)
                    .foregroundStyle(.secondary)
            } else {
                if let top = top, top.seconds > 0 {
                    HStack(spacing: 6) {
                        Text(top.title)
                            .font(AppFont.footnote)
                        Text("\(Int((Double(top.seconds) / Double(total) * 100).rounded()))%")
                            .font(AppFont.footnote.monospacedDigit())
                            .foregroundStyle(Color(hex: "#2E626B"))
                        Spacer()
                        Text(StatsStore.formatted(top.seconds))
                            .font(AppFont.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(shares.indices, id: \.self) { index in
                    let share = shares[index]
                    let ratio = total > 0 ? Double(share.seconds) / Double(total) : 0
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(share.title)
                                .font(AppFont.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int((ratio * 100).rounded()))%")
                                .font(AppFont.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(uiColor: .tertiarySystemFill))
                                Capsule()
                                    .fill(Color(hex: "#2E626B"))
                                    .frame(width: max(2, proxy.size.width * ratio))
                            }
                        }
                        .frame(height: 5)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 排行

    private var ranking: [(book: Book?, seconds: Int)] {
        Array(store.stats.bookRanking(in: range).prefix(8)).map { item in
            (library.books.first { $0.id.uuidString == item.id }, item.seconds)
        }
    }

    private var rankingCard: some View {
        let items = ranking
        let maxSeconds = max(items.first?.seconds ?? 1, 1)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("阅读排行")
                    .font(AppFont.headline)
                Spacer()
                Text(period == .total ? "全部时间" : period.title)
                    .font(AppFont.caption2)
                    .foregroundStyle(.secondary)
            }

            if items.isEmpty {
                Text("这个范围内还没有阅读记录")
                    .font(AppFont.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(AppFont.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 16, alignment: .leading)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.book?.title ?? "未知书籍")
                                .font(AppFont.footnote)
                                .lineLimit(1)
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color(uiColor: .tertiarySystemFill))
                                    Capsule()
                                        .fill(Color(hex: "#2E626B"))
                                        .frame(width: max(2, proxy.size.width * CGFloat(item.seconds) / CGFloat(maxSeconds)))
                                }
                            }
                            .frame(height: 4)
                        }
                        Spacer(minLength: 4)
                        Text(StatsStore.formatted(item.seconds))
                            .font(AppFont.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - 图表

    private func barChart(title: String, points: [DailyStatPoint], height: CGFloat) -> some View {
        let total = points.reduce(0) { $0 + $1.seconds }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(AppFont.headline)
                Spacer()
                Text(StatsStore.formatted(total))
                    .font(AppFont.caption2)
                    .foregroundStyle(.secondary)
            }

            Chart(points) { point in
                BarMark(
                    x: .value("日期", point.date, unit: .day),
                    y: .value("分钟", point.minutes)
                )
                .foregroundStyle(Color(hex: "#2E626B"))
                .cornerRadius(3)
            }
            .frame(height: height)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: points.count > 10 ? 6 : points.count)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func heatmapCard() -> some View {
        let points = store.dailySeries(days: 70)
        let maxSeconds = max(points.map { $0.seconds }.max() ?? 0, 60)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("阅读日历")
                    .font(AppFont.headline)
                Spacer()
                Text("最近 10 周")
                    .font(AppFont.caption2)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7),
                spacing: 3
            ) {
                ForEach(points) { point in
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(heatColor(point.seconds, maxSeconds: maxSeconds))
                        .frame(height: 15)
                }
            }

            HStack(spacing: 5) {
                Text("少")
                    .font(AppFont.caption2)
                    .foregroundStyle(.secondary)
                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(heatColor(Int(Double(maxSeconds) * level), maxSeconds: maxSeconds))
                        .frame(width: 11, height: 11)
                }
                Text("多")
                    .font(AppFont.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func heatColor(_ seconds: Int, maxSeconds: Int) -> Color {
        if seconds <= 0 {
            return Color(uiColor: .tertiarySystemFill)
        }
        let ratio = min(1.0, Double(seconds) / Double(max(1, maxSeconds)))
        return Color(hex: "#2E626B").opacity(0.2 + 0.8 * ratio)
    }
}