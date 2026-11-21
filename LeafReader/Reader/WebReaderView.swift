import SwiftUI
import UIKit
import WebKit

struct WebReaderView: UIViewRepresentable {
    let fileURL: URL
    let readAccessRoot: URL
    let css: String
    let restoreRatio: Double
    let resetPosition: Bool
    let onProgress: (Double) -> Void
    let onTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.allowsInlineMediaPlayback = true
        configuration.userContentController.addUserScript(
            WKUserScript(source: ReaderStyle.bootstrapJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )
        configuration.userContentController.add(context.coordinator, name: "progress")
        configuration.userContentController.add(context.coordinator, name: "ready")
        configuration.userContentController.add(context.coordinator, name: "tap")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.showsVerticalScrollIndicator = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        let key = fileURL.path
        if coordinator.loadedKey != key {
            coordinator.loadedKey = key
            coordinator.latestRatio = restoreRatio
            coordinator.appliedCSS = ""
            webView.loadFileURL(fileURL, allowingReadAccessTo: readAccessRoot)
            return
        }

        if coordinator.appliedCSS != css {
            coordinator.applyConfig(on: webView, restore: coordinator.latestRatio, reset: false)
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        let controller = webView.configuration.userContentController
        controller.removeScriptMessageHandler(forName: "progress")
        controller.removeScriptMessageHandler(forName: "ready")
        controller.removeScriptMessageHandler(forName: "tap")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebReaderView
        var loadedKey: String = ""
        var appliedCSS: String = ""
        var latestRatio: Double = 0

        init(_ parent: WebReaderView) {
            self.parent = parent
            self.latestRatio = parent.restoreRatio
        }

        func applyConfig(on webView: WKWebView, restore: Double, reset: Bool) {
            appliedCSS = parent.css
            let json = ReaderStyle.configJSON(css: parent.css, restore: restore, reset: reset)
            webView.evaluateJavaScript("window.__leaf && window.__leaf.applyConfig(\(json));", completionHandler: nil)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            latestRatio = parent.restoreRatio
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
                var value: Double?
                if let number = message.body as? NSNumber {
                    value = number.doubleValue
                } else if let double = message.body as? Double {
                    value = double
                }
                if let ratio = value {
                    latestRatio = ratio
                    parent.onProgress(ratio)
                }
            case "tap":
                parent.onTap()
            default:
                break
            }
        }
    }
}