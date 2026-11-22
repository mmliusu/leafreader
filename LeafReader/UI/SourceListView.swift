import SwiftUI
import UniformTypeIdentifiers

struct SourceListView: View {
    @EnvironmentObject private var sourceStore: BookSourceStore
    @Environment(\.dismiss) private var dismiss

    @State private var showFilePicker = false
    @State private var showPaste = false
    @State private var pastedText = ""
    @State private var alertMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if sourceStore.sources.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("还没有书源")
                                .font(AppFont.headline)
                            Text("导入 Legado / 阅读3.0 导出的书源 JSON，就能搜索网络书籍。支持 CSS、JSONPath、正则与 @js 规则。")
                                .font(AppFont.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    ForEach(sourceStore.groups, id: \.name) { group in
                        Section(group.name) {
                            ForEach(group.sources) { source in
                                row(source)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("书源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showFilePicker = true
                        } label: {
                            Label("从文件导入", systemImage: "doc.badge.plus")
                        }
                        Button {
                            showPaste = true
                        } label: {
                            Label("粘贴 JSON", systemImage: "doc.on.clipboard")
                        }
                        if !sourceStore.sources.isEmpty {
                            Button(role: .destructive) {
                                sourceStore.removeAll()
                            } label: {
                                Label("清空全部", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showFilePicker) {
                SourceFilePicker(isPresented: $showFilePicker) { urls in
                    importURLs(urls)
                }
            }
            .sheet(isPresented: $showPaste) {
                pasteSheet
            }
            .alert("书源", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("知道了", role: .cancel) { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private func row(_ source: BookSource) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(source.displayName)
                    .font(AppFont.body)
                    .lineLimit(1)
                Text(source.host)
                    .font(AppFont.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(
                get: { source.isEnabled },
                set: { sourceStore.setEnabled($0, for: source) }
            ))
            .labelsHidden()
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                sourceStore.remove(source)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private var pasteSheet: some View {
        NavigationStack {
            TextEditor(text: $pastedText)
                .font(.system(.footnote, design: .monospaced))
                .padding(8)
                .navigationTitle("粘贴书源 JSON")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") { showPaste = false }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("导入") {
                            let count = sourceStore.importString(pastedText)
                            showPaste = false
                            pastedText = ""
                            alertMessage = count > 0
                                ? "已导入 \(count) 个书源"
                                : (sourceStore.lastError ?? "导入失败")
                        }
                        .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
        }
    }

    private func importURLs(_ urls: [URL]) {
        var total = 0
        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { continue }
            total += sourceStore.importData(data)
        }
        alertMessage = total > 0
            ? "已导入 \(total) 个书源"
            : (sourceStore.lastError ?? "没有可导入的书源")
    }
}

struct SourceFilePicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPick: ([URL]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.json, .plainText, .data]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let parent: SourceFilePicker

        init(_ parent: SourceFilePicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onPick(urls)
            parent.isPresented = false
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}