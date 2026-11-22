import SwiftUI

struct AppearanceView: View {
    @AppStorage("ui.font") private var uiFontRaw = UIFontChoice.jinling.rawValue
    @AppStorage("ui.base") private var baseSize = 16.0
    @AppStorage("ui.appearance") private var appearance = "system"

    var body: some View {
        Form {
            Section("字体") {
                Picker("界面字体", selection: $uiFontRaw) {
                    ForEach(UIFontChoice.allCases) { choice in
                        Text(choice.title).tag(choice.rawValue)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("界面字号")
                            .font(AppFont.body)
                        Spacer()
                        Text("\(Int(baseSize)) pt")
                            .font(AppFont.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $baseSize, in: 13...22, step: 1)
                }

                Text("示例：墨阅 · 阅读让生活慢下来")
                    .font(AppFont.body)
                    .foregroundStyle(.secondary)
            } header: {
                Text("字号")
            } footer: {
                Text("只影响界面（书架、列表、按钮等）；阅读正文的字号在阅读界面「排版」里调整。")
            }

            Section("显示模式") {
                Picker("显示模式", selection: $appearance) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("外观")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutView: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("应用", value: "墨阅 LeafReader")
                LabeledContent("版本", value: version)
                LabeledContent("书源引擎", value: "Legado 兼容")
            }
            Section("说明") {
                Text("本地阅读器，支持 TXT / EPUB / PDF，以及 Legado 书源。所有数据保存在本机，可通过备份在两台设备间同步。")
                    .font(AppFont.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}