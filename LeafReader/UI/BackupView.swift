import SwiftUI
import UniformTypeIdentifiers

struct BackupView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var sourceStore: BookSourceStore

    @AppStorage("sync.last") private var lastSyncStamp: Double = 0

    @State private var showExporter = false
    @State private var exportURL: URL?
    @State private var showImporter = false
    @State private var message: String?
    @State private var showClearConfirm = false

    var body: some View {
        Form {
            Section {
                Button {
                    exportBackup()
                } label: {
                    Label("导出到文件", systemImage: "square.and.arrow.up")
                }
                Button {
                    showImporter = true
                } label: {
                    Label("从文件导入", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("本地备份")
            } footer: {
                Text("包含书架、阅读进度、书源、书签和阅读统计，不含书籍文件。")
            }

            Section {
                NavigationLink {
                    CloudBackupView()
                } label: {
                    Label("坚果云（WebDAV）", systemImage: "cloud")
                }
            } header: {
                Text("云备份")
            } footer: {
                Text("在两台设备上填写同一个坚果云账号，即可用同一份备份文件同步。")
            }

            if lastSyncStamp > 0 {
                Section {
                    LabeledContent("上次同步", value: lastSyncText)
                }
            }

            Section {
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label("清除所有统计记录", systemImage: "trash")
                }
            } header: {
                Text("数据管理")
            } footer: {
                Text("只清除阅读时长、翻页、字数与打开次数等统计，不会删除书架、书源、书签和阅读进度。")
            }
        }
        .navigationTitle("备份与恢复")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExporter) {
            if let url = exportURL {
                ExportFilePicker(urls: [url]) {
                    showExporter = false
                }
            }
        }
        .sheet(isPresented: $showImporter) {
            SourceFilePicker(isPresented: $showImporter) { urls in
                importBackup(urls)
            }
        }
        .confirmationDialog("清除所有统计记录？", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("清除", role: .destructive) {
                StatsStore.shared.reset()
                message = "已清除全部统计记录"
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("阅读时长、翻页次数、阅读字数都会归零，此操作不可恢复。")
        }
        .alert("备份", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("好", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private var lastSyncText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: lastSyncStamp))
    }

    private func exportBackup() {
        guard let data = SyncService.encode(SyncService.makePackage()) else {
            message = "备份生成失败"
            return
        }
        let url = SyncService.localBackupURL()
        do {
            try data.write(to: url, options: .atomic)
            exportURL = url
            showExporter = true
        } catch {
            message = "写入失败：\(error.localizedDescription)"
        }
    }

    private func importBackup(_ urls: [URL]) {
        guard let url = urls.first else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            message = "读取备份文件失败"
            return
        }
        message = SyncService.applyReport(data, source: "文件")
    }
}

struct CloudBackupView: View {
    @AppStorage("sync.dav.server") private var server = "https://dav.jianguoyun.com/dav/"
    @AppStorage("sync.dav.username") private var username = ""
    @AppStorage("sync.dav.password") private var password = ""
    @AppStorage("sync.dav.path") private var path = SyncService.defaultPath
    @AppStorage("sync.last") private var lastSyncStamp: Double = 0

    @State private var syncing = false
    @State private var message: String?

    private var config: WebDAVClient.Config {
        WebDAVClient.Config(server: server, username: username, password: password, path: path)
    }

    var body: some View {
        Form {
            Section {
                TextField("服务器", text: $server)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                TextField("账号（坚果云邮箱）", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                SecureField("应用密码", text: $password)
                TextField("远程路径", text: $path)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("账号")
            } footer: {
                Text("坚果云 → 账户信息 → 安全选项 → 第三方应用管理 → 添加应用，生成应用密码（不是登录密码）。")
            }

            Section {
                Button {
                    upload()
                } label: {
                    HStack {
                        Label("上传备份", systemImage: "icloud.and.arrow.up")
                        Spacer()
                        if syncing { ProgressView() }
                    }
                }
                .disabled(syncing || !config.isConfigured)

                Button {
                    download()
                } label: {
                    Label("下载并合并", systemImage: "icloud.and.arrow.down")
                }
                .disabled(syncing || !config.isConfigured)
            } header: {
                Text("同步")
            } footer: {
                if lastSyncStamp > 0 {
                    Text("上次同步：\(lastSyncText)")
                }
            }
        }
        .navigationTitle("坚果云")
        .navigationBarTitleDisplayMode(.inline)
        .alert("云备份", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("好", role: .cancel) { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private var lastSyncText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: lastSyncStamp))
    }

    private func upload() {
        guard let data = SyncService.encode(SyncService.makePackage()) else { return }
        syncing = true
        Task {
            do {
                try await WebDAVClient.upload(data, config: config)
                await MainActor.run {
                    syncing = false
                    lastSyncStamp = Date().timeIntervalSince1970
                    message = "已上传到坚果云"
                }
            } catch {
                await MainActor.run {
                    syncing = false
                    message = "上传失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func download() {
        syncing = true
        Task {
            do {
                let data = try await WebDAVClient.download(config: config)
                await MainActor.run {
                    syncing = false
                    lastSyncStamp = Date().timeIntervalSince1970
                    message = SyncService.applyReport(data, source: "坚果云")
                }
            } catch {
                await MainActor.run {
                    syncing = false
                    message = "下载失败：\(error.localizedDescription)"
                }
            }
        }
    }
}

struct ExportFilePicker: UIViewControllerRepresentable {
    let urls: [URL]
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: urls, asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onFinish: () -> Void

        init(_ onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onFinish()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onFinish()
        }
    }
}