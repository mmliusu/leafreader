import SwiftUI
import UIKit

// MARK: - 封面

/// 书架里的封面：优先用导入的封面图，没有就用按书 ID 生成的深色渐变 + 格式标签。
struct ShelfCoverView: View {
    let book: Book
    var cornerRadius: CGFloat = 10

    @EnvironmentObject private var library: LibraryStore
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: book.format.symbolName)
                        .font(.system(size: 22, weight: .light))
                    Text(book.format.displayName)
                        .font(AppFont.caption2)
                }
                .foregroundStyle(.white.opacity(0.92))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear(perform: loadCover)
    }

    private var gradientColors: [Color] {
        let palettes: [[Color]] = [
            [Color(hex: "#2F4858"), Color(hex: "#33658A")],
            [Color(hex: "#5B3A29"), Color(hex: "#8C5E3C")],
            [Color(hex: "#3C3B54"), Color(hex: "#6D5C7B")],
            [Color(hex: "#254E45"), Color(hex: "#3F7A62")],
            [Color(hex: "#4A2C2A"), Color(hex: "#7E4A46")]
        ]
        let total = book.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palettes[total % palettes.count]
    }

    private func loadCover() {
        guard image == nil, let url = library.coverURL(for: book) else { return }
        image = UIImage(contentsOfFile: url.path)
    }
}

// MARK: - 网格卡片

struct ShelfGridCell: View {
    let book: Book
    let category: String?
    let showCategory: Bool

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ShelfCoverView(book: book)
                .aspectRatio(0.68, contentMode: .fit)
                .overlay(alignment: .bottom) { progressBar }
                .shadow(color: .black.opacity(scheme == .dark ? 0.4 : 0.14), radius: 6, x: 0, y: 3)

            Text(book.title)
                .font(AppFont.footnote)
                .foregroundStyle(ShelfStyle.primaryText(scheme))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Text(book.displayAuthor)
                    .font(AppFont.caption2)
                    .foregroundStyle(ShelfStyle.secondaryText(scheme))
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(book.progressText)
                    .font(AppFont.caption2)
                    .foregroundStyle(ShelfStyle.secondaryText(scheme))
                    .monospacedDigit()
            }

            if showCategory, let category = category {
                Text(category)
                    .font(AppFont.caption2)
                    .foregroundStyle(ShelfStyle.accent)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ShelfStyle.accentSoft, in: Capsule())
            }
        }
        .contentShape(Rectangle())
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.25))
                Capsule()
                    .fill(Color.white.opacity(book.progress > 0.001 ? 0.92 : 0))
                    .frame(width: proxy.size.width * CGFloat(min(max(book.progress, 0), 1)))
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 6)
        .padding(.bottom, 6)
        .opacity(book.progress > 0.001 ? 1 : 0)
    }
}

// MARK: - 列表行

struct ShelfListRow: View {
    let book: Book
    let category: String?
    let showCategory: Bool
    let showCover: Bool

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 12) {
            if showCover {
                ShelfCoverView(book: book, cornerRadius: 6)
                    .frame(width: 44, height: 62)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(AppFont.callout)
                    .foregroundStyle(ShelfStyle.primaryText(scheme))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(book.displayAuthor)
                        .font(AppFont.caption)
                        .foregroundStyle(ShelfStyle.secondaryText(scheme))
                        .lineLimit(1)

                    if showCategory, let category = category {
                        Text(category)
                            .font(AppFont.caption2)
                            .foregroundStyle(ShelfStyle.accent)
                            .lineLimit(1)
                    }
                }

                Text(progressLine)
                    .font(AppFont.caption2)
                    .foregroundStyle(ShelfStyle.secondaryText(scheme))
            }

            Spacer(minLength: 0)

            Text(book.progressText)
                .font(AppFont.caption)
                .foregroundStyle(ShelfStyle.accent)
                .monospacedDigit()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var progressLine: String {
        if book.progress >= 0.995 { return "已读完" }
        if book.lastOpenedAt == nil { return "未开始阅读" }
        return "读到这里 \(book.progressText)"
    }
}

// MARK: - 书架顶部展示

struct ShelfTopSection: View {
    let style: ShelfTopStyle
    let books: [Book]
    let onOpen: (Book) -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            switch style {
            case .off:
                EmptyView()
            case .recent:
                recentStrip
            case .simulated:
                simulatedShelf
            case .spines:
                spineShelf
            case .today:
                todayCard
            }
        }
    }

    private var recentBooks: [Book] {
        Array(books.sorted { ($0.lastOpenedAt ?? $0.addedAt) > ($1.lastOpenedAt ?? $1.addedAt) }.prefix(3))
    }

    private var recentStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近阅读")
                .font(AppFont.caption)
                .foregroundStyle(ShelfStyle.secondaryText(scheme))

            HStack(spacing: 12) {
                ForEach(recentBooks) { book in
                    Button {
                        onOpen(book)
                    } label: {
                        HStack(spacing: 10) {
                            ShelfCoverView(book: book, cornerRadius: 6)
                                .frame(width: 40, height: 56)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(book.title)
                                    .font(AppFont.caption)
                                    .foregroundStyle(ShelfStyle.primaryText(scheme))
                                    .lineLimit(2)
                                Text(book.progressText)
                                    .font(AppFont.caption2)
                                    .foregroundStyle(ShelfStyle.accent)
                                Text(durationText(for: book))
                                    .font(AppFont.caption2)
                                    .foregroundStyle(ShelfStyle.secondaryText(scheme))
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(ShelfStyle.card(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var simulatedShelf: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(Array(recentBooks.enumerated()), id: \.offset) { index, book in
                    Button {
                        onOpen(book)
                    } label: {
                        ShelfCoverView(book: book, cornerRadius: 4)
                            .frame(width: 72, height: 104)
                            .rotationEffect(.degrees(index == 1 ? 0 : (index == 0 ? -3 : 3)), anchor: .bottom)
                            .shadow(color: .black.opacity(0.22), radius: 5, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)

            // 木架
            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#C9A27B"), Color(hex: "#9C7651")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 8)
                Rectangle()
                    .fill(Color.black.opacity(0.12))
                    .frame(height: 2)
                    .offset(y: 4)
            }
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }

    private var spineShelf: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(recentBooks.enumerated()), id: \.offset) { index, book in
                    Button {
                        onOpen(book)
                    } label: {
                        ZStack {
                            LinearGradient(
                                colors: spineColors(index),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            Text(book.title)
                                .font(AppFont.caption2)
                                .foregroundStyle(.white.opacity(0.94))
                                .lineLimit(1)
                                .fixedSize()
                                .rotationEffect(.degrees(-90))
                        }
                        .frame(width: 26, height: 128)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 1)
            }
        }
    }

    private func spineColors(_ index: Int) -> [Color] {
        let palettes: [[Color]] = [
            [Color(hex: "#33658A"), Color(hex: "#22404F")],
            [Color(hex: "#8C5E3C"), Color(hex: "#5B3A29")],
            [Color(hex: "#6D5C7B"), Color(hex: "#3C3B54")],
            [Color(hex: "#3F7A62"), Color(hex: "#254E45")],
            [Color(hex: "#7E4A46"), Color(hex: "#4A2C2A")]
        ]
        return palettes[index % palettes.count]
    }

    private var todayCard: some View {
        let today = StatsStore.shared.dailySeries(days: 1).last
        let seconds = today?.seconds ?? 0
        let turns = today?.pageTurns ?? 0
        let chars = today?.chars ?? 0

        return VStack(alignment: .leading, spacing: 10) {
            Text("今日")
                .font(AppFont.caption)
                .foregroundStyle(ShelfStyle.secondaryText(scheme))

            HStack(spacing: 10) {
                metric(ReadingStats.formatted(seconds), "阅读时长")
                metric("\(turns)", "翻页")
                metric(ReadingStats.formattedChars(chars), "字数")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ShelfStyle.card(scheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(AppFont.headline)
                .foregroundStyle(ShelfStyle.accent)
                .monospacedDigit()
            Text(label)
                .font(AppFont.caption2)
                .foregroundStyle(ShelfStyle.secondaryText(scheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(ShelfStyle.inset(scheme), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func durationText(for book: Book) -> String {
        let seconds = StatsStore.shared.seconds(for: book.id)
        return seconds > 0 ? "共 " + ReadingStats.formatted(seconds) : "还没开始"
    }
}

// MARK: - 空状态

struct ShelfEmptyState: View {
    let onImport: () -> Void
    let onSearchSource: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            ZStack {
                Circle()
                    .fill(ShelfStyle.accent.opacity(scheme == .dark ? 0.16 : 0.10))
                    .frame(width: 132, height: 132)
                Image(systemName: "book")
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(ShelfStyle.accent)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(ShelfStyle.accent.opacity(0.7))
                            .offset(x: 16, y: -4)
                    }
            }
            .padding(.bottom, 22)

            Text("开启你的阅读旅程")
                .font(AppFont.title3.bold())
                .foregroundStyle(ShelfStyle.primaryText(scheme))

            Text("The shelves are waiting for your next great discovery.")
                .font(AppFont.footnote.italic())
                .foregroundStyle(ShelfStyle.secondaryText(scheme))
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .padding(.horizontal, 28)

            HStack(spacing: 12) {
                actionCard(title: "本地导入", detail: "TXT / EPUB / PDF", symbol: "folder", action: onImport)
                actionCard(title: "书源找书", detail: "搜索网络书城", symbol: "magnifyingglass", action: onSearchSource)
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity)
    }

    private func actionCard(
        title: String,
        detail: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(ShelfStyle.accentSoft)
                        .frame(width: 34, height: 34)
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(ShelfStyle.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.callout)
                        .foregroundStyle(ShelfStyle.primaryText(scheme))
                    Text(detail)
                        .font(AppFont.caption2)
                        .foregroundStyle(ShelfStyle.secondaryText(scheme))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(ShelfStyle.card(scheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(ShelfStyle.separator(scheme), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}