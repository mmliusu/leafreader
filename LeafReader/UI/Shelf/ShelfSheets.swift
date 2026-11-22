import SwiftUI

// MARK: - 搜索页（独立全屏页：胶囊搜索框 + 检索维度 chips）

enum ShelfSearchDim: String, CaseIterable, Identifiable {
    case title
    case author
    case category

    var id: String { rawValue }

    var title: String {
        switch self {
        case .title: return "书名"
        case .author: return "作者"
        case .category: return "分类"
        }
    }
}

struct ShelfSearchPage: View {
    let books: [Book]
    let onOpen: (Book) -> Void

    @EnvironmentObject private var sourceStore: BookSourceStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var query = ""
    @State private var dims: Set<ShelfSearchDim> = Set(ShelfSearchDim.allCases)
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(ShelfStyle.accent)
                }

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundStyle(ShelfStyle.secondaryText(scheme))
                    TextField("搜索书架", text: $query)
                        .textFieldStyle(.plain)
                        .focused($focused)
                        .submitLabel(.search)
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(ShelfStyle.secondaryText(scheme))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(ShelfStyle.inset(scheme), in: Capsule())
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ShelfSearchDim.allCases) { dim in
                        Button {
                            if dims.contains(dim) {
                                dims.remove(dim)
                            } else {
                                dims.insert(dim)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: dims.contains(dim) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 12))
                                Text(dim.title)
                                    .font(AppFont.caption)
                            }
                            .foregroundStyle(dims.contains(dim) ? ShelfStyle.accent : ShelfStyle.secondaryText(scheme))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().stroke(
                                    dims.contains(dim) ? ShelfStyle.accent.opacity(0.5) : ShelfStyle.separator(scheme),
                                    lineWidth: 1
                                )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(results) { book in
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                onOpen(book)
                            }
                        } label: {
                            ShelfListRow(
                                book: book,
                                category: ShelfCategory.title(for: book, sources: sourceStore),
                                showCategory: true,
                                showCover: true
                            )
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)

                        if book.id != results.last?.id {
                            Divider().padding(.leading, 72)
                        }
                    }
                }
                .padding(.top, 6)
            }
            .overlay {
                if results.isEmpty {
                    Text(query.isEmpty ? "输入关键词开始搜索" : "没有匹配的书")
                        .font(AppFont.footnote)
                        .foregroundStyle(ShelfStyle.secondaryText(scheme))
                }
            }
        }
        .padding(.top, 14)
        .background(ShelfStyle.background(scheme).ignoresSafeArea())
        .onAppear { focused = true }
    }

    private var results: [Book] {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return [] }
        guard !dims.isEmpty else { return [] }
        return books.filter { book in
            var hit = false
            if dims.contains(.title), book.title.localizedCaseInsensitiveContains(keyword) { hit = true }
            if dims.contains(.author), book.displayAuthor.localizedCaseInsensitiveContains(keyword) { hit = true }
            if dims.contains(.category),
               ShelfCategory.title(for: book, sources: sourceStore).localizedCaseInsensitiveContains(keyword) {
                hit = true
            }
            return hit
        }
    }
}

// MARK: - 书架排序（底部弹层，分段选择器）

struct ShelfSortSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @AppStorage("shelf.sort") private var sortRaw = ShelfSortKey.recent.rawValue
    @AppStorage("shelf.desc") private var descending = true
    @AppStorage("shelf.categoryFirst") private var categoryFirst = true
    @AppStorage("shelf.filter") private var filterRaw = ShelfFilter.all.rawValue

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    group("排序方式") {
                        Picker("排序方式", selection: $sortRaw) {
                            ForEach(ShelfSortKey.allCases) { key in
                                Text(key.title).tag(key.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    group("排序顺序") {
                        Picker("排序顺序", selection: $descending) {
                            Text("降序").tag(true)
                            Text("升序").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    group("分类位置") {
                        Picker("分类位置", selection: $categoryFirst) {
                            Text("分类优先").tag(true)
                            Text("参与排序").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    group("阅读状态") {
                        Picker("阅读状态", selection: $filterRaw) {
                            ForEach(ShelfFilter.allCases) { option in
                                Text(option.title).tag(option.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }
                .padding(18)
            }
            .background(ShelfStyle.background(scheme).ignoresSafeArea())
            .navigationTitle("书架排序")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
            }
        }
    }

    private func group<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppFont.caption)
                .foregroundStyle(ShelfStyle.secondaryText(scheme))
            content()
        }
    }
}

// MARK: - 工具箱（底部弹层，图标网格）

struct ShelfToolboxSheet: View {
    let onFullTextSearch: () -> Void
    let onRandomPreview: () -> Void
    let onSourceSearch: () -> Void
    let onImport: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    tile("全文搜索", "text.magnifyingglass", onFullTextSearch)
                    tile("随机预览", "shuffle", onRandomPreview)
                    tile("书源找书", "server.rack", onSourceSearch)
                    tile("导入文件", "doc.badge.plus", onImport)
                }
                .padding(16)
            }
            .background(ShelfStyle.background(scheme).ignoresSafeArea())
            .navigationTitle("工具箱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func tile(_ title: String, _ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(ShelfStyle.accent)
                    .frame(height: 30)
                Text(title)
                    .font(AppFont.callout)
                    .foregroundStyle(ShelfStyle.primaryText(scheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(ShelfStyle.card(scheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 书架顶部展示（全屏设置页）

struct ShelfTopSettingsView: View {
    @Binding var topRaw: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(ShelfTopStyle.allCases) { style in
                    Button {
                        topRaw = style.rawValue
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: style.symbol)
                                .font(.system(size: 17, weight: .light))
                                .foregroundStyle(ShelfStyle.accent)
                                .frame(width: 26)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(style.title)
                                    .font(AppFont.callout)
                                    .foregroundStyle(ShelfStyle.primaryText(scheme))
                                Text(style.detail)
                                    .font(AppFont.caption2)
                                    .foregroundStyle(ShelfStyle.secondaryText(scheme))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 0)

                            if topRaw == style.rawValue {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(ShelfStyle.accent)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ShelfStyle.card(scheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(
                                    topRaw == style.rawValue ? ShelfStyle.accent.opacity(0.6) : ShelfStyle.separator(scheme),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(ShelfStyle.background(scheme).ignoresSafeArea())
        .navigationTitle("书架顶部展示")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
        }
    }
}