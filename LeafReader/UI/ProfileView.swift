import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var sourceStore: BookSourceStore

    @AppStorage("ui.font") private var uiFontRaw = UIFontChoice.jinling.rawValue
    @AppStorage("ui.scale") private var uiScaleRaw = 1.0
    @AppStorage("ui.appearance") private var appearance = "system"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("字体", selection: $uiFontRaw) {
                        ForEach(UIFontChoice.allCases) { choice in
                            Text(choice.title).tag(choice.rawValue)
                        }
                    }
                    Picker("字号", selection: $uiScaleRaw) {
                        Text("小").tag(0.9)
                        Text("标准").tag(1.0)
                        Text("大").tag(1.12)
                        Text("特大").tag(1.25)
                    }
                    Picker("显示模式", selection: $appearance) {
                        Text("跟随系统").tag("system")
                        Text("浅色").tag("light")
                        Text("深色").tag("dark")
                    }
                } header: {
                    Text("外观")
                } footer: {
                    Text("界面字体与字号立即生效；阅读正文的字体请在阅读界面的「排版」里单独设置。")
                }

                Section {
                    NavigationLink {
                        BackupView()
                            .environmentObject(library)
                            .environmentObject(sourceStore)
                    } label: {
                        Label("备份与恢复", systemImage: "externaldrive")
                    }
                } header: {
                    Text("备份")
                } footer: {
                    Text("本地文件备份，或通过坚果云在两台设备之间同步。")
                }

                Section("关于") {
                    LabeledContent("应用", value: "墨阅 LeafReader")
                    LabeledContent("版本", value: appVersion)
                    LabeledContent("书源引擎", value: "Legado 兼容")
                }
            }
            .navigationTitle("我的")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}