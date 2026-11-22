import SwiftUI
import Charts

struct StatsModuleView: View {
    let id: String
    let context: StatsContext

    @ViewBuilder
    var body: some View {
        switch id {
        case "total.companion": companionCard
        case "total.overview": totalOverview
        case "total.recent9": recent9Card
        case "total.heartbeat": heartbeatCard
        case "total.recent30": recent30Card
        case "total.longest": longestCard
        case "day.overview": dayOverview
        case "day.efficiency": efficiencyCard
        case "day.habit": habitCard
        case "day.highlights": highlightsCard
        case "day.period": periodCard("时间分布", "不同时段阅读占比")
        case "day.hourly": hourlyCard
        case "day.ranking": rankingCard
        case "week.overview", "month.overview", "year.overview": periodOverview
        case "week.time", "month.time": timeAnalysis
        case "week.favorite": weekFavorite
        case "week.period", "year.period": periodCard("阅读时间分布", "24 小时阅读习惯一览")
        case "week.behavior", "month.behavior": behaviorCard
        case "week.preference", "month.preference": preferenceCard
        case "week.persistence", "month.persistence": persistenceCard
        case "month.calendar": monthCalendarCard(showDuration: false)
        case "month.duration": monthCalendarCard(showDuration: true)
        case "month.heatmap": monthHeatmap
        case "year.heatmap": yearHeatmap
        case "year.habit": yearHabit
        case "year.monthFavorite": monthFavorite
        case "year.records": yearRecords
        case "week.ranking", "month.ranking", "year.ranking": rankingCard
        default: EmptyView()
        }
    }

    // MARK: - 总

    private var companionCard: some View {
        let first = context.books.map { $0.addedAt }.min() ?? Date()
        let days = max(1, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: first), to: Calendar.current.startOfDay(for: Date())).day ?? 0)
        return StatsCard {
            VStack(spacing: 8) {
                Text("我们相识的第 \(days) 天")
                    .font(AppFont.size(20))
                    .foregroundStyle(StatsStyle.text)
                Text("从第一本书开始，一点一点累积")
                    .font(AppFont.caption2)
                    .foregroundStyle(StatsStyle.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }

    private var totalOverview: some View {
        StatsCard(title: "累计阅读", subtitle: "核心数据一览") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                StatsMetricTile(icon: "clock", value: StatsStore.formatted(context.stats.totalSeconds), label: "总阅读时长")
                StatsMetricTile(icon: "book", value: "\(context.books.count) 本", label: "文档数")
                StatsMetricTile(icon: "rectangle.on.rectangle", value: "\(context.stats.totalPageTurns) 页", label: "翻页次数")
                StatsMetricTile(icon: "textformat", value: StatsStore.formattedChars(context.stats.totalChars), label: "阅读字数")
                StatsMetricTile(icon: "bookmark", value: "\(context.inProgressBooks) 本", label: "在读")
                StatsMetricTile(icon: "checkmark.circle", value: "\(context.finishedBooks) 本", label: "已读")
            }
        }
    }

    private var recent9Card: some View {
        let points = StatsStore.shared.dailySeries(days: 9)
        return StatsCard(title: "最近 9 天", subtitle: "每日阅读时间（分钟）") {
            Chart(points) { point in
                BarMark(
                    x: .value("日期", point.date, unit: .day),
                    y: .value("分钟", point.minutes)
                )
                .foregroundStyle(StatsStyle.accent)
                .cornerRadius(4)
            }
            .frame(height: 130)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 9)) { _ in
                    AxisValueLabel(format: .dateTime.day())
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
        }
    }

    private var heartbeatCard: some View {
        let sessions = context.stats.sessionSeconds
        let buckets = sessionBuckets(sessions)
        return StatsCard(title: "阅读心跳", subtitle: "单次阅读时长分布（分钟）") {
            if sessions.isEmpty {
                StatsEmptyState(caption: "还没有阅读记录")
            } else {
                Chart(buckets.indices, id: \.self) { index in
                    BarMark(
                        x: .value("区间", buckets[index].title),
                        y: .value("次数", buckets[index].count)
                    )
                    .foregroundStyle(StatsStyle.accent)
                    .cornerRadius(4)
                }
                .frame(height: 120)
                .chartYAxis { AxisMarks(position: .leading) }
            }
        }
    }

    private func sessionBuckets(_ sessions: [Int]) -> [(title: String, count: Int)] {
        let titles = ["<5", "5-15", "15-30", "30-60", ">60"]
        var counts = [0, 0, 0, 0, 0]
        for value in sessions {
            let minutes = value / 60
            if minutes < 5 { counts[0] += 1 }
            else if minutes < 15 { counts[1] += 1 }
            else if minutes < 30 { counts[2] += 1 }
            else if minutes < 60 { counts[3] += 1 }
            else { counts[4] += 1 }
        }
        return zip(titles, counts).map { ($0.0, $0.1) }
    }

    private var recent30Card: some View {
        let points = StatsStore.shared.dailySeries(days: 30)
        return StatsCard(title: "最近 30 天", subtitle: "每日阅读时长") {
            StatsHeatGrid(points: points, columns: 10, cellHeight: 16)
            StatsHeatLegend()
        }
    }

    private var longestCard: some View {
        let items = Array(context.ranking.prefix(10))
        return StatsCard(title: "阅读时间最长的文件", subtitle: "前 10 个文件") {
            if items.isEmpty {
                StatsEmptyState(caption: "还没有阅读记录")
            } else {
                ForEach(items.indices, id: \.self) { index in
                    StatsRankRow(
                        index: index,
                        title: items[index].book?.title ?? "未知书籍",
                        subtitle: "进度 \(items[index].book?.progressText ?? "--")",
                        value: StatsStore.formatted(items[index].seconds),
                        ratio: Double(items[index].seconds) / Double(max(items.first?.seconds ?? 1, 1))
                    )
                }
            }
        }
    }

    // MARK: - 日

    private var dayOverview: some View {
        StatsCard(title: "当日阅读总览", subtitle: "今天的阅读情况") {
            if !context.hasData {
                StatsEmptyState()
            } else {
                Text(StatsStore.formatted(context.seconds))
                    .font(AppFont.size(28))
                    .foregroundStyle(StatsStyle.text)
                HStack(spacing: 0) {
                    StatsMetricTile(icon: "folder", value: "\(context.readingBooks)", label: "文件数")
                    StatsMetricTile(icon: "rectangle.on.rectangle", value: "\(context.turns)", label: "翻页次数")
                    StatsMetricTile(icon: "arrow.up.right.square", value: "\(context.opens)", label: "打开次数")
                }
            }
        }
    }

    private var efficiencyCard: some View {
        StatsCard(title: "效率指标", subtitle: "关键阅读效率分析") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                StatsInnerMetric(
                    title: "平均阅读",
                    subtitle: "每本书",
                    value: String(format: "%.1f", Double(context.seconds) / 60.0 / Double(max(context.readingBooks, 1))),
                    unit: "分钟"
                )
                StatsInnerMetric(
                    title: "翻页速度",
                    subtitle: "平均时间",
                    value: context.turns > 0 ? String(format: "%.1f", Double(context.seconds) / Double(context.turns)) : "N/A",
                    unit: "秒/页"
                )
                StatsInnerMetric(
                    title: "阅读效率",
                    subtitle: "翻页率",
                    value: context.seconds > 0 ? String(format: "%.1f", Double(context.turns) / (Double(context.seconds) / 60.0)) : "N/A",
                    unit: "页/分钟"
                )
                StatsInnerMetric(
                    title: "使用频次",
                    subtitle: "平均打开",
                    value: String(format: "%.1f", Double(context.opens) / Double(max(context.readingBooks, 1))),
                    unit: "次/书"
                )
            }
        }
    }

    private var habitCard: some View {
        let session = context.stats.sessionSummary()
        let shares = context.periodShares
        let top = shares.max { $0.seconds < $1.seconds }
        let active = context.seconds > 0 ? min(100, Int(Double(context.seconds) / 864.0)) : 0
        return StatsCard(title: "阅读习惯分析", subtitle: "了解你的阅读偏好") {
            StatsInfoRow(title: "专注度最高", value: session.longest > 0 ? StatsStore.formatted(session.longest) : "N/A")
            StatsInfoRow(title: "最佳阅读时段", value: (top?.seconds ?? 0) > 0 ? (top?.title ?? "N/A") : "N/A")
            StatsInfoRow(title: "阅读活跃度", value: context.seconds > 0 ? "\(active)%" : "N/A")
        }
    }

    private var highlightsCard: some View {
        let ranking = context.ranking
        let opened = context.openRanking
        let firstHour = context.period == .day ? context.stats.dailyFirstHour[ReadingStats.dayKey(context.anchor)] : nil
        let lastHour = context.period == .day ? context.stats.dailyLastHour[ReadingStats.dayKey(context.anchor)] : nil

        return StatsCard(title: "当日之最", subtitle: "今日阅读记录亮点") {
            StatsBadgeRow(
                icon: "clock",
                title: "阅读最久",
                primary: ranking.first?.book?.title ?? "N/A",
                secondary: ranking.first.map { StatsStore.formatted($0.seconds) } ?? "N/A"
            )
            StatsBadgeRow(
                icon: "rectangle.on.rectangle",
                title: "翻页最多",
                primary: ranking.first?.book?.title ?? "N/A",
                secondary: "\(context.turns) 页"
            )
            StatsBadgeRow(
                icon: "hand.tap",
                title: "打开最多",
                primary: opened.first?.book?.title ?? "N/A",
                secondary: opened.first.map { "\($0.opens) 次" } ?? "N/A"
            )
            StatsBadgeRow(
                icon: "sunrise",
                title: "最早打开",
                primary: firstHour.map { String(format: "%02d:00", $0) } ?? "N/A",
                secondary: ""
            )
            StatsBadgeRow(
                icon: "moon",
                title: "最晚打开",
                primary: lastHour.map { String(format: "%02d:00", $0) } ?? "N/A",
                secondary: ""
            )
        }
    }

    private func periodCard(_ title: String, _ subtitle: String) -> some View {
        StatsCard(title: title, subtitle: subtitle) {
            if context.seconds <= 0 {
                StatsEmptyState(caption: "还没有阅读记录")
            } else {
                StatsPeriodBars(shares: context.periodShares)
            }
        }
    }

    private var hourlyCard: some View {
        let hours = context.hours
        let maxValue = max(hours.max() ?? 0, 1)
        let peak = hours.indices.max { hours[$0] < hours[$1] }
        return StatsCard(title: "时段阅读详情", subtitle: "每小时的阅读活动") {
            if context.seconds <= 0 {
                StatsEmptyState(caption: "0% N/A")
            } else {
                HStack {
                    Text(peak.map { String(format: "%02d:00 - %02d:00", $0, min($0 + 1, 24)) } ?? "N/A")
                        .font(AppFont.footnote)
                        .foregroundStyle(StatsStyle.text)
                    Spacer()
                    Text(StatsStore.formatted(context.seconds))
                        .font(AppFont.caption2)
                        .foregroundStyle(StatsStyle.secondary)
                }
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<24, id: \.self) { hour in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(StatsStyle.accent)
                            .frame(height: max(2, CGFloat(hours[hour]) / CGFloat(maxValue) * 44))
                    }
                }
                .frame(height: 46)
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text("0:00").font(AppFont.caption2).foregroundStyle(StatsStyle.secondary)
                    Spacer()
                    Text("12:00").font(AppFont.caption2).foregroundStyle(StatsStyle.secondary)
                    Spacer()
                    Text("24:00").font(AppFont.caption2).foregroundStyle(StatsStyle.secondary)
                }
            }
        }
    }

    private var rankingCard: some View {
        let items = context.ranking
        let subtitle: String
        switch context.period {
        case .day: subtitle = "当日阅读的所有书籍"
        case .week: subtitle = "当周阅读的所有书籍"
        case .month: subtitle = "当月阅读的所有书籍"
        case .year: subtitle = "当年阅读的所有书籍"
        case .total: subtitle = "全部阅读记录"
        }
        return StatsCard(title: "阅读排行", subtitle: subtitle) {
            if items.isEmpty {
                StatsEmptyState(caption: "还没有阅读记录")
            } else {
                ForEach(items.indices, id: \.self) { index in
                    StatsRankRow(
                        index: index,
                        title: items[index].book?.title ?? "未知书籍",
                        subtitle: "进度 \(items[index].book?.progressText ?? "--")",
                        value: StatsStore.formatted(items[index].seconds),
                        ratio: Double(items[index].seconds) / Double(max(items.first?.seconds ?? 1, 1))
                    )
                }
            }
        }
    }

    // MARK: - 周 / 月 / 年

    private var periodOverview: some View {
        StatsCard(title: "\(context.period.title)度总览", subtitle: "核心数据一览") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                StatsMetricTile(icon: "clock", value: StatsStore.formatted(context.seconds), label: "总时长")
                StatsMetricTile(icon: "book", value: "\(context.readingBooks)", label: "书籍数")
                StatsMetricTile(icon: "textformat", value: StatsStore.formattedChars(context.chars), label: "总字数")
                StatsMetricTile(icon: "hand.tap", value: "\(context.opens)", label: "打开次数")
                StatsMetricTile(icon: "rectangle.on.rectangle", value: "\(context.turns)", label: "总翻页")
                StatsMetricTile(icon: "calendar", value: StatsStore.formatted(context.dailyAverage), label: "日均时长")
            }
        }
    }

    private var timeAnalysis: some View {
        let shares = context.periodShares
        return StatsCard(title: "时间分析", subtitle: "阅读时间分布与趋势") {
            HStack(spacing: 10) {
                StatsInnerMetric(
                    title: "日均时长",
                    subtitle: "按天平均",
                    value: StatsStore.formatted(context.dailyAverage),
                    unit: ""
                )
                StatsInnerMetric(
                    title: "日均书籍",
                    subtitle: "按天平均",
                    value: String(format: "%.1f", Double(context.readingBooks) / Double(max(context.days, 1))),
                    unit: "本"
                )
            }
            StatsPeriodBars(shares: shares)
        }
    }

    private var weekFavorite: some View {
        let days = weekDays()
        return StatsCard(title: "本周最爱", subtitle: "按天展示阅读时间最长的书籍") {
            ForEach(days.indices, id: \.self) { index in
                let day = days[index]
                HStack(spacing: 8) {
                    Text(day.label)
                        .font(AppFont.caption2)
                        .foregroundStyle(StatsStyle.accent)
                        .frame(width: 54, alignment: .leading)
                    Text(day.bookTitle ?? "-")
                        .font(AppFont.caption2)
                        .foregroundStyle(StatsStyle.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(day.seconds > 0 ? StatsStore.formatted(day.seconds) : "-")
                        .font(AppFont.caption2.monospacedDigit())
                        .foregroundStyle(StatsStyle.secondary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(StatsStyle.inner.opacity(day.seconds > 0 ? 1 : 0.4))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private func weekDays() -> [(label: String, bookTitle: String?, seconds: Int)] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        var result: [(label: String, bookTitle: String?, seconds: Int)] = []
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: context.range.start) else { continue }
            let key = ReadingStats.dayKey(date)
            let seconds = context.stats.seconds(on: date)
            let map = context.stats.dailyBookSeconds[key] ?? [:]
            let best = map.max { $0.value < $1.value }
            let title = best.flatMap { pair -> String? in
                context.books.first { $0.id.uuidString == pair.key }?.title
            }
            let weekday = Calendar.current.component(.weekday, from: date)
            let name = ["日", "一", "二", "三", "四", "五", "六"][max(0, min(6, weekday - 1))]
            result.append(("\(name) \(formatter.string(from: date))", title, seconds))
        }
        return result
    }

    private var behaviorCard: some View {
        let session = context.stats.sessionSummary()
        let shares = context.periodShares
        let top = shares.max { $0.seconds < $1.seconds }
        let streak = context.stats.continuousDays()
        return StatsCard(title: "行为分析", subtitle: "阅读习惯深度分析") {
            StatsInfoRow(title: "翻页之王", value: "\(context.turns) 页")
            StatsInfoRow(title: "精力最集中", value: (top?.seconds ?? 0) > 0 ? (top?.title ?? "N/A") : "N/A")
            StatsInfoRow(title: "最长一次阅读", value: session.longest > 0 ? StatsStore.formatted(session.longest) : "N/A")
            StatsInfoRow(title: "长期陪伴", value: "\(streak) 天")
        }
    }

    private var preferenceCard: some View {
        let ranking = context.ranking
        let opened = context.openRanking
        let firstHour = context.stats.dailyFirstHour[ReadingStats.dayKey(context.anchor)]
        let lastHour = context.stats.dailyLastHour[ReadingStats.dayKey(context.anchor)]
        return StatsCard(title: "书籍偏好", subtitle: "你的阅读倾向") {
            StatsInfoRow(title: "最爱阅读", value: ranking.first?.book?.title ?? "N/A")
            StatsInfoRow(title: "最常打开", value: opened.first?.book?.title ?? "N/A")
            StatsInfoRow(title: "阅读最早", value: firstHour.map { String(format: "%02d:00", $0) } ?? "N/A")
            StatsInfoRow(title: "阅读最晚", value: lastHour.map { String(format: "%02d:00", $0) } ?? "N/A")
        }
    }

    private var persistenceCard: some View {
        let best = context.stats.bestDay(in: context.period == .total ? nil : context.range)
        let streak = context.stats.continuousDays()
        return StatsCard(title: "毅力成就", subtitle: "坚持就是胜利") {
            StatsInfoRow(title: "最长连续阅读", value: "\(streak) 天")
            StatsInfoRow(title: "单日最佳记录", value: best.map { StatsStore.formatted($0.seconds) } ?? "N/A")
            if let best = best {
                StatsInfoRow(title: "最佳记录日期", value: StatsRange.label(period: .day, anchor: best.date))
            }
        }
    }

    private func monthCalendarCard(showDuration: Bool) -> some View {
        StatsCard(title: showDuration ? "阅读时长月历" : "月历 · 活跃日历", subtitle: "每天的阅读情况") {
            StatsMonthGrid(month: context.anchor, secondsByDay: context.stats.dailySeconds)
            StatsHeatLegend()
        }
    }

    private var monthHeatmap: some View {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: context.anchor) ?? 1..<31
        let points: [DailyStatPoint] = range.compactMap { day in
            var comps = calendar.dateComponents([.year, .month], from: context.anchor)
            comps.day = day
            guard let date = calendar.date(from: comps) else { return nil }
            return DailyStatPoint(
                date: date,
                seconds: context.stats.seconds(on: date),
                pageTurns: context.stats.pageTurns(on: date),
                chars: context.stats.chars(on: date)
            )
        }
        return StatsCard(title: "活跃热力图", subtitle: "每日阅读时长分布") {
            StatsHeatGrid(points: points, columns: 15, cellHeight: 14)
            StatsHeatLegend()
        }
    }

    private var yearHeatmap: some View {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: context.anchor)
        let points: [DailyStatPoint] = (1...12).compactMap { month in
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.day = 1
            guard let date = calendar.date(from: comps) else { return nil }
            let range = calendar.range(of: .day, in: .month, for: date) ?? 1..<29
            var total = 0
            for day in range {
                var d = comps
                d.day = day
                if let item = calendar.date(from: d) {
                    total += context.stats.seconds(on: item)
                }
            }
            return DailyStatPoint(date: date, seconds: total, pageTurns: 0, chars: 0)
        }
        return StatsCard(title: "年度热力图", subtitle: "每月阅读时长") {
            StatsHeatGrid(points: points, columns: 12, cellHeight: 22)
            StatsHeatLegend()
        }
    }

    private var yearHabit: some View {
        let streak = context.stats.continuousDays()
        let weekday = context.stats.activeWeekday(in: context.period == .total ? nil : context.range)
        let weekdayName = weekday.map { ["日", "一", "二", "三", "四", "五", "六"][max(0, min(6, $0 - 1))] } ?? "N/A"
        let sessions = context.stats.sessionSeconds
        let immersive = sessions.filter { $0 >= 30 * 60 }.count
        let fragmented = sessions.filter { $0 < 10 * 60 }.count

        return StatsCard(title: "阅读习惯", subtitle: "深入了解你的阅读模式") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                StatsMetricTile(icon: "moon.stars", value: "\(immersive) 天", label: "沉浸式阅读")
                StatsMetricTile(icon: "flame", value: "\(fragmented) 天", label: "碎片化阅读")
                StatsMetricTile(icon: "calendar", value: "周\(weekdayName)", label: "最活跃日")
                StatsMetricTile(icon: "textformat", value: "\(streak) 天", label: "最长连续")
            }
        }
    }

    private var monthFavorite: some View {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: context.anchor)
        var rows: [(label: String, title: String?, seconds: Int)] = []
        for month in 1...12 {
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.day = 1
            guard let date = calendar.date(from: comps) else { continue }
            let range = calendar.range(of: .day, in: .month, for: date) ?? 1..<29
            var totals: [String: Int] = [:]
            for day in range {
                var d = comps
                d.day = day
                guard let item = calendar.date(from: d) else { continue }
                let key = ReadingStats.dayKey(item)
                for (book, seconds) in context.stats.dailyBookSeconds[key] ?? [:] {
                    totals[book, default: 0] += seconds
                }
            }
            let best = totals.max { $0.value < $1.value }
            let title = best.flatMap { pair -> String? in
                context.books.first { $0.id.uuidString == pair.key }?.title
            }
            rows.append(("\(month) 月", title, best?.value ?? 0))
        }

        return StatsCard(title: "月度最爱", subtitle: "每个月阅读时间最长的书籍") {
            ForEach(rows.indices, id: \.self) { index in
                let row = rows[index]
                HStack(spacing: 8) {
                    Text(row.label)
                        .font(AppFont.caption2)
                        .foregroundStyle(StatsStyle.accent)
                        .frame(width: 42, alignment: .leading)
                    Text(row.title ?? "-")
                        .font(AppFont.caption2)
                        .foregroundStyle(StatsStyle.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(row.seconds > 0 ? StatsStore.formatted(row.seconds) : "-")
                        .font(AppFont.caption2.monospacedDigit())
                        .foregroundStyle(StatsStyle.secondary)
                }
                .padding(.vertical, 3)
            }
        }
    }

    private var yearRecords: some View {
        let best = context.stats.bestDay(in: context.period == .total ? nil : context.range)
        let busiest = context.books.max { $0.progress < $1.progress }
        return StatsCard(title: "年度记录", subtitle: "值得纪念的阅读瞬间") {
            StatsInfoRow(
                title: "最能读的一天",
                value: best.map { "\(StatsRange.label(period: .day, anchor: $0.date)) · \(StatsStore.formatted($0.seconds))" } ?? "N/A"
            )
            StatsInfoRow(
                title: "进度最靠前",
                value: busiest.map { "\($0.title) · \($0.progressText)" } ?? "N/A"
            )
            StatsInfoRow(title: "总翻页", value: "\(context.turns) 页")
            StatsInfoRow(title: "总字数", value: StatsStore.formattedChars(context.chars))
        }
    }
}

// MARK: - 模块设置

struct StatsModuleEditor: View {
    let all: [String]
    let visible: [String]
    let onSave: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var order: [String] = []
    @State private var checked: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(order, id: \.self) { id in
                        Button {
                            toggle(id)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: checked.contains(id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(checked.contains(id) ? StatsStyle.accent : StatsStyle.secondary)
                                Text(StatsDefaults.title(id))
                                    .font(AppFont.body)
                                    .foregroundStyle(StatsStyle.text)
                                Spacer()
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(StatsStyle.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onMove { order.move(fromOffsets: $0, toOffset: $1) }
                } header: {
                    Text("点击勾选显示，长按拖动排序")
                }

                Section {
                    Button("恢复默认") {
                        order = all
                        checked = Set(all)
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("统计模块设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定") {
                        onSave(order.filter { checked.contains($0) })
                        dismiss()
                    }
                }
            }
            .onAppear {
                if order.isEmpty {
                    order = visible + all.filter { !visible.contains($0) }
                    checked = Set(visible)
                }
            }
        }
    }

    private func toggle(_ id: String) {
        if checked.contains(id) {
            checked.remove(id)
        } else {
            checked.insert(id)
        }
    }
}

// MARK: - 分享

struct ShareImageView: View {
    let image: UIImage

    var body: some View {
        ShareSheet(items: [image])
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}