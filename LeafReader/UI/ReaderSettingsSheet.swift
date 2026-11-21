import SwiftUI

struct ReaderSettingsSheet: View {
    @EnvironmentObject private var settings: ReadingSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Text("A").font(.system(size: 12))
                        Slider(value: $settings.fontSize, in: 14...32, step: 1)
                        Text("A").font(.system(size: 21))
                    }
                } header: {
                    Text("字号（\(Int(settings.fontSize))）")
                }

                Section {
                    Slider(value: $settings.lineHeight, in: 1.2...2.6, step: 0.05)
                } header: {
                    Text("行距（\(String(format: "%.2f", settings.lineHeight))）")
                }

                Section {
                    Slider(value: $settings.margin, in: 8...40, step: 2)
                } header: {
                    Text("左右边距（\(Int(settings.margin))）")
                }

                Section("阅读方式") {
                    Picker("阅读方式", selection: $settings.pageMode) {
                        Text("左右翻页").tag(true)
                        Text("上下滚动").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section("字体") {
                    Picker("字体", selection: $settings.font) {
                        ForEach(ReaderFont.allCases) { font in
                            Text(font.name).tag(font)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("背景") {
                    HStack(spacing: 10) {
                        ForEach(ReaderTheme.allCases) { theme in
                            themeButton(theme)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func themeButton(_ theme: ReaderTheme) -> some View {
        Button {
            settings.theme = theme
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(theme.backgroundColor)
                        .frame(width: 34, height: 34)
                    Circle()
                        .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
                        .frame(width: 34, height: 34)
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .frame(width: 38, height: 38)
                        .opacity(settings.theme == theme ? 1 : 0)
                }
                Text(theme.name)
                    .font(AppFont.caption2)
                    .foregroundStyle(settings.theme == theme ? Color.accentColor : Color.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}