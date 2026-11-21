import SwiftUI

@main
struct LeafReaderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var library = LibraryStore.shared
    @StateObject private var settings = ReadingSettings.shared

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(library)
                .environmentObject(settings)
                .environment(\.font, AppFont.body)
        }
    }
}