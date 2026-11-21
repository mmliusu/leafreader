import SwiftUI
import UIKit

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var settings: ReadingSettings

    @State private var showImporter = false
    @State private var openedBook: Book?
    @State private var pendingDelete: Book?
    @State private var showError = false

    private let columns = [
        GridItem(.adaptive(minimum: 104, maximum: 150), spacing: 18, alignment: .top)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if library.sortedBooks.isEmpty {
                    emptyState
                } else {
                    bookGrid
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("书架")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("导入书籍")
                }
            }
        }
        .sheet(isPresented: $showImporter) {
            DocumentPickerView(isPresented: $showImporter) { urls in
                for url in urls {
                    _ = library.importBook(from: url)
                }
            }
        }
        .fullScreenCover(item: $openedBook) { book in
            ReaderView(book: book)
                .environmentObject(library)
                .environmentObject(settings)
        }
        .confirmationDialog(
            "删除《\(pendingDelete?.title ?? "")》？",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let book = pendingDelete {
                    library.delete(book)
                }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text("书文件会从设备上移除，此操作不可恢复。")
        }
        .alert("导入失败", isPresented: $showError) {
            Button("知道了", role: .cancel) {
                library.lastError = nil
            }
        } message: {
            Text(library.lastError ?? "")
        }
        .onChange(of: library.lastError) { value in
            showError = (value != nil)
        }
        .onOpenURL { url in
            library.importIncomingFile(at: url)
        }
    }

    private var bookGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 22) {
                ForEach(library.sortedBooks) { book in
                    BookCard(book: book)
                        .onTapGesture {
                            openedBook = book
                        }
                        .contextMenu {
                            Button {
                                pendingDelete = book
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                            Button {
                                library.resetProgress(book)
                            } label: {
                                Label("标记为未读", systemImage: "arrow.counterclockwise")
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "books.vertical")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(.secondary)
            Text("书架还是空的")
                .font(AppFont.headline)
            Text("导入 TXT、EPUB 或 PDF 开始阅读")
                .font(AppFont.footnote)
                .foregroundStyle(.secondary)
            Button {
                showImporter = true
            } label: {
                Label("导入书籍", systemImage: "plus")
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}