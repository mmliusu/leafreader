import SwiftUI
import UIKit
import WebKit

struct WebReaderView: UIViewRepresentable {
    let fileURL: URL
    let readAccessRoot: URL
    let css: String
    let pageMode: Bool
    let reloadToken: String
    let restoreRatio: Double
    let resetPosition: Bool
    let onProgress: (Double) -> Void
    let onPages: (Int, Int) -> Void
    let onChapterChange: (Int) -> Void
    let onTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        configuration.userContentController.addUserScript(
            WKUserScript(source: ReaderStyle.bootstrapJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )
        for name in ["progress", "pages", "chapter", "ready", "tap", "page"] {
            configuration.userContentController.add(context.coordinator, name: name)
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.alwaysBounceVertical = false
        context.coordinator.webView = webView
        webView.scrollView.isPagingEnabled = pageMode
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        if webView.scrollView.isPagingEnabled != pageMode {
            webView.scrollView.isPagingEnabled = pageMode
        }

        let key = fileURL.path + "|" + reloadToken
        if coordinator.loadedKey != key {
            coordinator.loadedKey = key
            coordinator.latestRatio = restoreRatio
            coordinator.appliedSignature = ""
            webView.loadFileURL(fileURL, allowingReadAccessTo: readAccessRoot)
            return
        }

        let signature = css + "|" + (pageMode ? "page" : "scroll")
        if coordinator.appliedSignature != signature {
            coordinator.applyConfig(on: webView, restore: coordinator.latestRatio, reset: false)
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        let controller = webView.configuration.userContentController
        for name in ["progress", "pages", "chapter", "ready", "tap", "page"] {
            controller.removeScriptMessageHandler(forName: name)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebReaderView
        weak var webView: WKWebView?
        var loadedKey: String = ""
        var appliedSignature: String = ""
        var latestRatio: Double = 0

        init(_ parent: WebReaderView) {
            self.parent = parent
            self.latestRatio = parent.restoreRatio
        }

        func applyConfig(on webView: WKWebView, restore: Double, reset: Bool) {
            appliedSignature = parent.css + "|" + (parent.pageMode ? "page" : "scroll")
            let json = ReaderStyle.configJSON(
                css: parent.css,
                mode: parent.pageMode ? "page" : "scroll",
                restore: restore,
                reset: reset
            )
            webView.evaluateJavaScript("window.__leaf && window.__leaf.applyConfig(\(json));", completionHandler: nil)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            latestRatio = parent.restoreRatio
            webView.scrollView.isPagingEnabled = parent.pageMode
            applyConfig(on: webView, restore: parent.restoreRatio, reset: parent.resetPosition)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            if navigationAction.navigationType == .linkActivated,
               !url.isFileURL,
               let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "progress", "ready":
                if let ratio = number(from: message.body) {
                    latestRatio = ratio
                    parent.onProgress(ratio)
                }
            case "pages":
                guard let dict = message.body as? [String: Any] else { return }
                let current = (dict["current"] as? NSNumber)?.intValue ?? (dict["current"] as? Int) ?? 0
                let total = (dict["total"] as? NSNumber)?.intValue ?? (dict["total"] as? Int) ?? 1
                parent.onPages(current, total)
            case "chapter":
                guard let raw = message.body as? String else { return }
                if raw == "next" {
                    parent.onChapterChange(1)
                } else if raw == "prev" {
                    parent.onChapterChange(-1)
                }
            case "page":
                let delta = (message.body as? NSNumber)?.intValue ?? 0
                if delta != 0 {
                    webView?.evaluateJavaScript("window.__leaf && window.__leaf.goPage(\(delta));", completionHandler: nil)
                }
            case "tap":
                parent.onTap()
            default:
                break
            }
        }

        private func number(from body: Any) -> Double? {
            if let value = body as? NSNumber { return value.doubleValue }
            if let value = body as? Double { return value }
            if let value = body as? Int { return Double(value) }
            return nil
        }
    }
}