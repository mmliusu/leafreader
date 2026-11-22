import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var sourceStore: BookSourceStore
    @EnvironmentObject private var settings: ReadingSettings

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
    }
}

struct StatsTabView: View {
    var body: some View {
        StatsView(standalone: true)
    }
}