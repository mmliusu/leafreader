import SwiftUI

struct BookmarkListView: View {
    let onAdd: () -> Bookmark
    let onSelect: (Bookmark) -> Void
    let onDelete: (Bookmark) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var items: [Bookmark]

    init(
        bookmarks: [Bookmark],
        onAdd: @escaping () -> Bookmark,
        onSelect: @escaping (Bookmark) -> Void,
        onDelete: @escaping (Bookmark) -> Void
    ) {
        self.onAdd = onAdd
        self.onSelect = onSelect
        self.onDelete = onDelete
        _items = State(initialValue: bookmarks)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        let mark = onAdd()
                        items.append(mark)
                        items.sort { lhs, rhs in
                            lhs.chapterIndex == rhs.chapterIndex
                                ? lhs.progress < rhs.progress
                                : lhs.chapterIndex < rhs.chapterIndex
                        }
                    } label: {
                        Label("添加当前位置书签", systemImage: "bookmark.fill")
                    }
                }

                if items.isEmpty {
                    Section {
                        Text("还没有书签。阅读时点上面的按钮就能记住当前位置。")
                            .font(AppFont.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("书签（\(items.count)）") {
                        ForEach(items) { mark in
                            Button {
                                onSelect(mark)
                                dismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "bookmark")
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mark.chapterTitle)
                                            .font(AppFont.body)
                                            .lineLimit(1)
                                        Text("\(mark.positionLabel) · \(mark.dateLabel)")
                                            .font(AppFont.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            for index in offsets where index < items.count {
                                onDelete(items[index])
                            }
                            items.remove(atOffsets: offsets)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("书签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}