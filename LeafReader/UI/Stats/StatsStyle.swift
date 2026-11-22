import SwiftUI

enum StatsStyle {
    static let accent = Color(hex: "#2E86DE")
    static let accentLight = Color(hex: "#589EE5")
    static let background = Color(hex: "#FAFAFA")
    static let card = Color.white
    static let inner = Color(hex: "#F2F7FB")
    static let text = Color(hex: "#444444")
    static let secondary = Color(hex: "#787878")

    static let heatEmpty = Color(hex: "#DDDDDD")
    static let heat: [Color] = [
        Color(hex: "#93C0EE"),
        Color(hex: "#79B2EA"),
        Color(hex: "#61A3E6"),
        Color(hex: "#4795E2"),
        Color(hex: "#2E86DE")
    ]

    static func heatColor(seconds: Int) -> Color {
        guard seconds > 0 else { return heatEmpty }
        let minutes = Double(seconds) / 60.0
        if minutes < 30 { return heat[0] }
        if minutes < 60 { return heat[1] }
        if minutes < 180 { return heat[2] }
        if minutes < 360 { return heat[3] }
        return heat[4]
    }
}

struct StatsCard<Content: View>: View {
    var title: String?
    var subtitle: String?
    var trailing: AnyView?
    let content: () -> Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        trailing: AnyView? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(AppFont.headline)
                            .foregroundStyle(StatsStyle.text)
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(AppFont.caption2)
                                .foregroundStyle(StatsStyle.secondary)
                        }
                    }
                    Spacer(minLength: 8)
                    if let trailing = trailing {
                        trailing
                    }
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StatsStyle.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// 2×3 / 2×2 指标格：图标 + 数值 + 灰标签
struct StatsMetricTile: View {
    let icon: String
    let value: String
    let label: String
    var tint: Color = StatsStyle.accent

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(tint)
            Text(value)
                .font(AppFont.size(17))
                .foregroundStyle(StatsStyle.text)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(label)
                .font(AppFont.caption2)
                .foregroundStyle(StatsStyle.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

/// 内嵌浅蓝小卡（效率指标）
struct StatsInnerMetric: View {
    let title: String
    let subtitle: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(AppFont.caption2)
                .foregroundStyle(StatsStyle.accent)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(AppFont.size(19))
                    .foregroundStyle(StatsStyle.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(unit)
                    .font(AppFont.caption2)
                    .foregroundStyle(StatsStyle.secondary)
            }
            Text(subtitle)
                .font(AppFont.caption2)
                .foregroundStyle(StatsStyle.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(StatsStyle.inner)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct StatsInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(AppFont.footnote)
                .foregroundStyle(StatsStyle.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(value)
                .font(AppFont.footnote)
                .foregroundStyle(StatsStyle.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

/// 带圆形图标徽章的列表行
struct StatsBadgeRow: View {
    let icon: String
    let title: String
    let primary: String
    let secondary: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(StatsStyle.inner)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(StatsStyle.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.caption2)
                    .foregroundStyle(StatsStyle.secondary)
                Text(primary)
                    .font(AppFont.footnote)
                    .foregroundStyle(StatsStyle.text)
                    .lineLimit(1)
                if !secondary.isEmpty {
                    Text(secondary)
                        .font(AppFont.caption2)
                        .foregroundStyle(StatsStyle.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct StatsHeatGrid: View {
    let points: [DailyStatPoint]
    var columns: Int = 10
    var cellHeight: CGFloat = 16

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns),
            spacing: 4
        ) {
            ForEach(points) { point in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(StatsStyle.heatColor(seconds: point.seconds))
                    .frame(height: cellHeight)
            }
        }
    }
}

struct StatsHeatLegend: View {
    var body: some View {
        HStack(spacing: 10) {
            legendItem(StatsStyle.heatEmpty, "未读")
            legendItem(StatsStyle.heat[0], "<30m")
            legendItem(StatsStyle.heat[1], "30-60m")
            legendItem(StatsStyle.heat[2], "1-3h")
            legendItem(StatsStyle.heat[3], "3-6h")
            legendItem(StatsStyle.heat[4], ">6h")
        }
        .font(AppFont.caption2)
        .foregroundStyle(StatsStyle.secondary)
    }

    private func legendItem(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 9, height: 9)
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

/// 横向条形排序行
struct StatsRankRow: View {
    let index: Int
    let title: String
    let subtitle: String
    let value: String
    let ratio: Double

    var body: some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(AppFont.caption2.monospacedDigit())
                .foregroundStyle(StatsStyle.secondary)
                .frame(width: 16, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFont.footnote)
                    .foregroundStyle(StatsStyle.text)
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppFont.caption2)
                        .foregroundStyle(StatsStyle.secondary)
                        .lineLimit(1)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(StatsStyle.inner)
                        Capsule()
                            .fill(StatsStyle.accent)
                            .frame(width: max(3, proxy.size.width * CGFloat(min(max(ratio, 0), 1))))
                    }
                }
                .frame(height: 5)
            }
            Spacer(minLength: 4)
            Text(value)
                .font(AppFont.caption2.monospacedDigit())
                .foregroundStyle(StatsStyle.secondary)
        }
    }
}

struct StatsEmptyState: View {
    var caption: String = "总阅读时长 0分0秒"

    var body: some View {
        VStack(spacing: 6) {
            Text("没！看！书！")
                .font(AppFont.size(24))
                .foregroundStyle(StatsStyle.accent)
            Text(caption)
                .font(AppFont.caption2)
                .foregroundStyle(StatsStyle.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

/// 四时段条
struct StatsPeriodBars: View {
    let shares: [(title: String, seconds: Int, icon: String)]

    private var total: Int { shares.reduce(0) { $0 + $1.seconds } }

    var body: some View {
        VStack(spacing: 9) {
            ForEach(shares.indices, id: \.self) { index in
                let share = shares[index]
                let ratio = total > 0 ? Double(share.seconds) / Double(total) : 0
                HStack(spacing: 8) {
                    Image(systemName: share.icon)
                        .font(.system(size: 13))
                        .foregroundStyle(StatsStyle.accent)
                        .frame(width: 18)
                    Text(share.title)
                        .font(AppFont.caption2)
                        .foregroundStyle(StatsStyle.secondary)
                        .frame(width: 74, alignment: .leading)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(StatsStyle.inner)
                            Capsule()
                                .fill(StatsStyle.accent)
                                .frame(width: max(2, proxy.size.width * CGFloat(ratio)))
                        }
                    }
                    .frame(height: 5)
                    Text(total > 0 ? "\(Int((ratio * 100).rounded()))%" : "N/A")
                        .font(AppFont.caption2.monospacedDigit())
                        .foregroundStyle(StatsStyle.secondary)
                        .frame(width: 34, alignment: .trailing)
                }
            }
        }
    }
}

/// 月历（浅蓝格 + 每日时长）
struct StatsMonthGrid: View {
    let month: Date
    let secondsByDay: [String: Int]

    private var calendar: Calendar { Calendar.current }

    private var dayCells: [Int?] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: first)
        var cells: [Int?] = Array(repeating: nil, count: firstWeekday - 1)
        cells.append(contentsOf: range.map { Optional($0) })
        return cells
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { title in
                    Text(title)
                        .font(AppFont.caption2)
                        .foregroundStyle(StatsStyle.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                spacing: 4
            ) {
                ForEach(dayCells.indices, id: \.self) { index in
                    if let day = dayCells[index] {
                        let key = keyFor(day: day)
                        let seconds = secondsByDay[key] ?? 0
                        VStack(spacing: 1) {
                            Text("\(day)")
                                .font(AppFont.caption2)
                                .foregroundStyle(StatsStyle.text)
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(StatsStyle.heatColor(seconds: seconds))
                                .frame(height: 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                        .background(StatsStyle.inner.opacity(seconds > 0 ? 1 : 0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    } else {
                        Color.clear.frame(height: 30)
                    }
                }
            }
        }
    }

    private func keyFor(day: Int) -> String {
        let comps = calendar.dateComponents([.year, .month], from: month)
        var components = DateComponents()
        components.year = comps.year
        components.month = comps.month
        components.day = day
        guard let date = calendar.date(from: components) else { return "" }
        return ReadingStats.dayKey(date)
    }
}