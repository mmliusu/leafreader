import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var sourceStore: BookSourceStore
    @EnvironmentObject private var settings: ReadingSettings

    @AppStorage("ui.font") private var uiFontRaw = UIFontChoice.jinling.rawValue
    @AppStorage("ui.scale") private var uiScaleRaw = 1.0
    @AppStorage("ui.appearance") private var appearance = "system"

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
        .id("\(uiFontRaw)-\(uiScaleRaw)")
    }
}

struct StatsTabView: View {
    var body: some View {
        StatsView(standalone: true)
    }
}