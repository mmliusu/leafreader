import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var sourceStore: BookSourceStore
    @EnvironmentObject private var settings: ReadingSettings

    @AppStorage("ui.appearance") private var appearance = "system"
    @AppStorage(AppFont.fontKey) private var uiFontRaw = UIFontChoice.jinling.rawValue
    @AppStorage(AppFont.baseKey) private var uiBaseRaw = 16.0

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    var body: some View {
        TabView {
            LibraryView()
                .environmentObject(library)
                .environmentObject(settings)
                .environmentObject(sourceStore)
                .tabItem {
                    Label("书架", systemImage: "books.vertical")
                }

            SourceDiscoverTabView()
                .environmentObject(sourceStore)
                .environmentObject(library)
                .tabItem {
                    Label("书源", systemImage: "server.rack")
                }

            StatsTabView()
                .tabItem {
                    Label("统计", systemImage: "chart.bar")
                }

            ProfileView()
                .environmentObject(library)
                .environmentObject(sourceStore)
                .tabItem {
                    Label("我的", systemImage: "person")
                }
        }
        .tint(Color(hex: "#2E626B"))
        .preferredColorScheme(colorScheme)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color(uiColor: .systemBackground), for: .tabBar)
        // 不再用 .id 强制重建：换字体会把 TabView 打回第一个 Tab。
        // 字号变化由 LeafReaderApp 里读取 @AppStorage 注入的 environment(\.font) 驱动刷新。
        .onChange(of: uiFontRaw) { _ in
            AppFont.invalidate()
        }
        .onChange(of: uiBaseRaw) { _ in
            AppFont.invalidate()
        }
    }
}

struct StatsTabView: View {
    var body: some View {
        StatsView(standalone: true)
    }
}