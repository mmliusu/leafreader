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
                VStack(alignment: .leading, spacing: 16) {
                    Picker("范围", selection: $period) {
                        ForEach(StatsPeriod.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    metricsGrid

                    Text("字数按每页约 400 字估算")
                        .font(AppFont.caption2)
                        .foregroundStyle(.secondary)

                    if period == .total {
                        barChart(title: "最近 7 天阅读时长", points: store.dailySeries(days: 7), height: 140)
                        barChart(title: "最近 30 天阅读时长", points: store.dailySeries(days: 30), height: 160)
                        topBooks
                    } else {
                        summaryCard
                    }

                    if !standalone {
                        Button(role: .destructive) {
                            showResetConfirm = true
                        } label: {
                            Label("清空阅读统计", systemImage: "trash")
                                .font(AppFont.footnote)
                        }
                        .padding(.top, 6)
                    }
                }
                .padding(16)
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
                Text("时长、翻页、字数记录都会被删除，书架和书源不受影响。")
            }
        }
    }

    // MARK: - 指标

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

    private var currentBooks: Int {
        guard let range = range else { return store.stats.lastRead.count }
        return store.stats.lastRead.values.filter { range.contains($0) }.count
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            metricCard("阅读时长", StatsStore.formatted(currentSeconds), "clock")
            metricCard("阅读书籍", "\(currentBooks) 本", "books.vertical")
            metricCard("翻页次数", "\(currentTurns) 次", "rectangle.on.rectangle")
            metricCard("阅读字数", StatsStore.formattedChars(currentChars), "textformat")
        }
    }

    private func metricCard(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 12))
                Text(title)
                    .font(AppFont.caption2)
            }
            .foregroundStyle(.secondary)
            Text(value)
                .font(AppFont.title3)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
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

    // MARK: - 周期摘要

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(period.title)统计")
                .font(AppFont.headline)
            Text(summaryLine)
                .font(AppFont.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var summaryLine: String {
        let seconds = StatsStore.formatted(currentSeconds)
        let chars = StatsStore.formattedChars(currentChars)
        switch period {
        case .day:
            return "今天阅读 \(seconds)，翻页 \(currentTurns) 次，约 \(chars)，涉及 \(currentBooks) 本书。"
        case .week:
            return "本周阅读 \(seconds)，翻页 \(currentTurns) 次，约 \(chars)，涉及 \(currentBooks) 本书。"
        case .month:
            return "本月阅读 \(seconds)，翻页 \(currentTurns) 次，约 \(chars)，涉及 \(currentBooks) 本书。"
        case .year:
            return "今年阅读 \(seconds)，翻页 \(currentTurns) 次，约 \(chars)，涉及 \(currentBooks) 本书。"
        case .total:
            return ""
        }
    }

    // MARK: - Top 10

    private var topBooks: some View {
        let ranked = library.books
            .map { ($0, store.seconds(for: $0.id)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
        let top = Array(ranked.prefix(10))

        return VStack(alignment: .leading, spacing: 10) {
            Text("阅读时长 Top 10")
                .font(AppFont.headline)

            if top.isEmpty {
                Text("还没有阅读记录")
                    .font(AppFont.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(top.indices, id: \.self) { index in
                    let book = top[index].0
                    let seconds = top[index].1
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(AppFont.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 18, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(book.title)
                                .font(AppFont.footnote)
                                .lineLimit(1)
                            Text("进度 \(book.progressText)")
                                .font(AppFont.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Text(StatsStore.formatted(seconds))
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
}