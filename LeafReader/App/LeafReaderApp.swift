import SwiftUI

@main
struct LeafReaderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var library = LibraryStore.shared
    @StateObject private var settings = ReadingSettings.shared
    @StateObject private var sourceStore = BookSourceStore.shared

    // 读取设置项，让界面字号/字体变化时这里重新求值，
    // 进而把新的 environment(\.font) 推给所有页面（不需要重建视图树）。
    @AppStorage(AppFont.fontKey) private var uiFontRaw = UIFontChoice.jinling.rawValue
    @AppStorage(AppFont.baseKey) private var uiBaseRaw = 16.0

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