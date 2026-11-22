import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var library: LibraryStore
    @ObservedObject private var store = StatsStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("总览") {
                    statRow("总阅读时长", StatsStore.formatted(store.stats.totalSeconds))
                    statRow("今天", StatsStore.formatted(store.todaySeconds()))
                    statRow("最近 7 天", StatsStore.formatted(store.weekSeconds()))
                }

                let ranked = library.books
                    .map { ($0, store.seconds(for: $0.id)) }
                    .filter { $0.1 > 0 }
                    .sorted { $0.1 > $1.1 }

                if ranked.isEmpty {
                    Section("每本书") {
                        Text("还没有阅读记录")
                            .font(AppFont.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("每本书") {
                        ForEach(ranked.indices, id: \.self) { index in
                            let book = ranked[index].0
                            let seconds = ranked[index].1
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(book.title)
                                        .font(AppFont.body)
                                        .lineLimit(1)
                                    Text("进度 \(book.progressText)")
                                        .font(AppFont.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 4)
                                Text(StatsStore.formatted(seconds))
                                    .font(AppFont.footnote.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        store.reset()
                    } label: {
                        Label("清空阅读统计", systemImage: "trash")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("阅读统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(AppFont.body)
            Spacer()
            Text(value)
                .font(AppFont.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}