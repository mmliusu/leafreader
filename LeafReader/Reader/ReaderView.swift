import SwiftUI

struct ReaderView: View {
    @StateObject private var model: ReaderViewModel
    @EnvironmentObject private var settings: ReadingSettings
    @Environment(\.dismiss) private var dismiss

    @State private var showMenu = true
    @State private var showTOC = false
    @State private var showSettings = false
    @State private var showSwitch = false
    @State private var showBookmarks = false
    @State private var showSearch = false
    @State private var bookmarks: [Bookmark] = []

    init(book: Book) {
        _model = StateObject(wrappedValue: ReaderViewModel(book: book))
    }

    var body: some View {
        ZStack {
            settings.theme.backgroundColor.ignoresSafeArea()
            readerContent
            if showMenu {
                menuOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showMenu)
        .statusBarHidden(!showMenu)
        .onAppear {
            LibraryStore.shared.markOpened(model.book.id)
            model.load()
        }
        .onDisappear {
            model.persistNow()
        }
        .sheet(isPresented: $showTOC) {
            TocSheet(
                sections: model.document?.sections ?? [],
                currentIndex: model.sectionIndex
            ) { index in
                model.goToSection(index)
                showTOC = false
            }
            .environmentObject(settings)
        }
        .sheet(isPresented: $showSettings) {
            ReaderSettingsSheet()
                .environmentObject(settings)
        }
        .sheet(isPresented: $showSwitch) {
            SourceSwitchView(
                bookTitle: model.book.title,
                excludeSourceID: model.book.sourceID ?? ""
            ) { result in
                performSwitch(result)
            }
        }
        .sheet(isPresented: $showBookmarks) {
            BookmarkListView(
                bookmarks: bookmarks,
                onAdd: { model.addBookmarkNow() },
                onSelect: { mark in jump(to: mark) },
                onDelete: { mark in
                    LibraryStore.shared.removeBookmark(id: mark.id, for: model.book)
                }
            )
        }
        .sheet(isPresented: $showSearch) {
            BookSearchView(sections: model.document?.sections ?? []) { hit, keyword in
                model.jump(to: hit, keyword: keyword)
            }
        }
        .alert("章节加载失败", isPresented: Binding(
            get: { model.chapterError != nil },
            set: { if !$0 { model.chapterError = nil } }
        )) {
            Button("知道了", role: .cancel) { model.chapterError = nil }
        } message: {
            Text(model.chapterError ?? "")
        }
    }

    // MARK: - 内容

    @ViewBuilder
    private var readerContent: some View {
        if model.isLoading {
            ProgressView()
                .tint(settings.theme.foregroundColor)
        } else if model.isLoadingChapter {
            VStack(spacing: 12) {
                ProgressView()
                Text("正在加载本章…")
                    .font(AppFont.footnote)
                    .foregroundStyle(.secondary)
            }
            .tint(settings.theme.foregroundColor)
        } else if let message = model.errorMessage {
            VStack(spacing: 18) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 34))
                Text(message)
                    .font(AppFont.callout)
                    .multilineTextAlignment(.center)
                Button("返回书架") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(32)
            .foregroundStyle(settings.theme.foregroundColor)
        } else if model.book.format == .pdf {
            PDFReaderView(
                url: LibraryStore.shared.fileURL(for: model.book),
                pageIndex: model.pdfPageIndex,
                theme: settings.theme,
                onPageChange: { index, count in
                    model.updatePDFPage(index, count: count)
                },
                onTap: { toggleMenu() }
            )
            .ignoresSafeArea()
        } else if let document = model.document,
                  let section = document.sections[safe: model.sectionIndex] {
            WebReaderView(
                fileURL: section.url,
                readAccessRoot: document.readAccessRoot,
                css: ReaderStyle.css(
                    settings: settings,
                    pageMode: settings.pageMode,
                    customFontURL: LibraryStore.shared.customFontURL
                ),
                pageMode: settings.pageMode,
                reloadToken: "\(model.reloadToken)",
                highlightTerm: model.highlightTerm,
                highlightToken: model.highlightToken,
                restoreRatio: model.sectionProgress,
                resetPosition: model.sectionProgress < 0.001,
                onProgress: { ratio in
                    model.updateSectionProgress(ratio)
                },
                onPages: { current, total in
                    model.updatePages(current: current, total: total)
                },
                onChapterChange: { delta in
                    if delta > 0 {
                        model.nextSection()
                    } else if delta < 0 {
                        model.previousSection()
                    }
                },
                onTap: { toggleMenu() }
            )
            .ignoresSafeArea()
        } else {
            Text("没有可显示的内容")
                .foregroundStyle(settings.theme.foregroundColor)
        }
    }

    // MARK: - 菜单

    private var menuOverlay: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: 0)
            bottomBar
        }
    }

    private var topBar: some View {
        HStack(spacing: 18) {
            Button {
                model.persistNow()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(AppFont.body)
            }

            Spacer(minLength: 8)

            VStack(spacing: 2) {
                Text(model.book.title)
                    .font(AppFont.headline)
                    .lineLimit(1)
                if let section = model.currentSection, model.book.format != .pdf {
                    Text(section.title)
                        .font(AppFont.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Button {
                showTOC = true
            } label: {
                Image(systemName: "list.bullet")
            }
            .disabled(model.book.format == .pdf || model.document == nil)
        }
        .font(AppFont.title3)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    private var bottomBar: some View {
        VStack(spacing: 14) {
            if model.book.format == .pdf {
                HStack {
                    Text("第 \(model.pdfPageIndex + 1) / \(max(model.pdfPageCount, 1)) 页")
                        .font(AppFont.footnote)
                    Spacer()
                    Text(model.progressText)
                        .font(AppFont.footnote)
                }
            } else {
                ProgressView(value: model.overallProgress)
                HStack {
                    Button {
                        model.previousSection()
                    } label: {
                        Label("上一章", systemImage: "chevron.left")
                    }
                    .disabled(model.sectionIndex <= 0)

                    Spacer()

                    Group {
                        if settings.pageMode && model.pageCount > 1 {
                            Text("第 \(model.pageIndex + 1) / \(model.pageCount) 页")
                        } else {
                            Text("\(model.sectionIndex + 1) / \(model.sectionCount) · \(Int((model.sectionProgress * 100).rounded()))%")
                        }
                    }
                    .font(AppFont.footnote)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        model.nextSection()
                    } label: {
                        Label("下一章", systemImage: "chevron.right")
                    }
                    .disabled(model.sectionIndex >= model.sectionCount - 1)
                }
                .font(AppFont.subheadline)
            }

            HStack(spacing: 16) {
                Button {
                    showSettings = true
                } label: {
                    Label("排版", systemImage: "textformat.size")
                }
                if model.book.format != .pdf {
                    Button {
                        bookmarks = LibraryStore.shared.bookmarks(for: model.book)
                        showBookmarks = true
                    } label: {
                        Label("书签", systemImage: "bookmark")
                    }
                    Button {
                        showSearch = true
                    } label: {
                        Label("搜索", systemImage: "magnifyingglass")
                    }
                }
                if model.book.isNetworkBook {
                    Button {
                        showSwitch = true
                    } label: {
                        Label("换源", systemImage: "arrow.left.arrow.right")
                    }
                }
                Button {
                    toggleMenu()
                } label: {
                    Label("沉浸", systemImage: "eye.slash")
                }
            }
            .font(AppFont.subheadline)
            .labelStyle(.titleAndIcon)
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 26)
        .background(.ultraThinMaterial)
    }

    private func jump(to mark: Bookmark) {
        model.jumpTo(chapterIndex: mark.chapterIndex, progress: mark.progress)
    }

    private func performSwitch(_ result: SourceSearchResult) {
        showSwitch = false
        guard let source = BookSourceStore.shared.source(id: result.sourceID) else { return }
        Task {
            guard let detail = try? await BookSourceEngine.detail(
                source: source,
                bookUrl: result.bookUrl,
                keyword: result.name,
                fallback: result
            ) else { return }
            await MainActor.run {
                let title = model.currentSection?.title ?? ""
                _ = LibraryStore.shared.switchSource(
                    book: model.book,
                    to: detail,
                    currentChapterTitle: title
                )
                dismiss()
            }
        }
    }

    private func toggleMenu() {
        withAnimation(.easeInOut(duration: 0.18)) {
            showMenu.toggle()
        }
    }
}