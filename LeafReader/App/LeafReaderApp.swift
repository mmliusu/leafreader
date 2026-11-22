import SwiftUI

@main
struct LeafReaderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var library = LibraryStore.shared
    @StateObject private var settings = ReadingSettings.shared
    @StateObject private var sourceStore = BookSourceStore.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(library)
                .environmentObject(settings)
                .environmentObject(sourceStore)
                .environment(\.font, AppFont.body)
        }
    }
}