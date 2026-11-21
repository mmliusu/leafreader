import UIKit

/// 负责接收“用其他应用打开/分享”进来的文件。
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        LibraryStore.shared.importIncomingFile(at: url)
        return true
    }
}