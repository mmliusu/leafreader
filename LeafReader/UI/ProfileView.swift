import SwiftUI
import UniformTypeIdentifiers

struct ProfileView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var sourceStore: BookSourceStore

    @AppStorage("sync.dav.server") private var server = "https://dav.jianguoyun.com/dav/"
    @AppStorage("sync.dav.username") private var username = ""
    @AppStorage("sync.dav.password") private var password = ""
    @AppStorage("sync.dav.path") private var path = SyncService.defaultPath
    @AppStorage("sync.last") private var lastSyncStamp: Double = 0

    @State private var showExporter = false
    @State private var exportURL: URL?
    @State private var showImporter = false
    @State private var syncing = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("数据概览") {
                    LabeledContent("书籍", value: "\(library.books.count) 本")
                    LabeledContent("书源", value: "\(sourceStore.sources.count) 个")
                    LabeledContent(
                        "总阅读时长",
                        value: StatsStore.formatted(StatsStore.shared.stats.totalSeconds)
                    )
                }

                Section {
                    Button {
                        exportBackup()
                    } label: {
                        Label("导出备份文件", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("从文件导入备份", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("本地备份")
                } footer: {
                    Text("备份包含书架元数据、阅读进度、书源、书签与阅读统计；书籍文件本身不包含。")
                }

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
                    Text("坚果云 WebDAV")
                } footer: {
                    Text("在坚果云「账户信息 → 安全选项 → 第三方应用管理」添加应用并生成应用密码。路径默认为根目录下的备份文件。")
                }

                Section {
                    Button {
                        uploadToCloud()
                    } label: {
                        HStack {
                            Label("上传到坚果云", systemImage: "icloud.and.arrow.up")
                            Spacer()
                            if syncing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(syncing || !davConfig.isConfigured)

                    Button {
                        downloadFromCloud()
                    } label: {
                        Label("从坚果云恢复", systemImage: "icloud.and.arrow.down")
                    }
                    .disabled(syncing || !davConfig.isConfigured)

                    if lastSyncStamp > 0 {
                        LabeledContent("上次同步", value: lastSyncText)
                    }
                } header: {
                    Text("云端同步")
                }

                Section("关于") {
                    LabeledContent("应用", value: "墨阅 LeafReader")
                    LabeledContent("版本", value: appVersion)
                    LabeledContent("书源引擎", value: "Legado 兼容")
                }
            }
            .navigationTitle("我的")
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
            .alert("同步", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("好", role: .cancel) { message = nil }
            } message: {
                Text(message ?? "")
            }
        }
    }

    // MARK: - 辅助

    private var davConfig: WebDAVClient.Config {
        WebDAVClient.Config(server: server, username: username, password: password, path: path)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var lastSyncText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: lastSyncStamp))
    }

    // MARK: - 本地备份

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
        applyBackup(data, source: "文件")
    }

    private func applyBackup(_ data: Data, source: String) {
        guard let package = SyncService.decode(data) else {
            message = SyncError.decode.errorDescription
            return
        }
        let result = SyncService.apply(package)
        message = "\(source)合并完成：书籍 \(result.books) 本、书源 \(result.sources) 个、书签 \(result.bookmarks) 条，阅读统计已合并"
    }

    // MARK: - 云端

    private func uploadToCloud() {
        guard let data = SyncService.encode(SyncService.makePackage()) else { return }
        syncing = true
        Task {
            do {
                try await WebDAVClient.upload(data, config: davConfig)
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

    private func downloadFromCloud() {
        syncing = true
        Task {
            do {
                let data = try await WebDAVClient.download(config: davConfig)
                await MainActor.run {
                    syncing = false
                    applyBackup(data, source: "坚果云")
                    lastSyncStamp = Date().timeIntervalSince1970
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