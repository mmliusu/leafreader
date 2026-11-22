import SwiftUI
import WebKit

struct BrowserPreview: View {
    let url: URL?
    let sourceName: String

    @Environment(\.dismiss) private var dismiss
    @State private var loading = true
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Group {
                if let url = url {
                    WebPage(url: url, loading: $loading, failed: $failed)
                        .overlay {
                            if loading {
                                ProgressView()
                            } else if failed {
                                Text("页面没有加载出来，可能被网站拦截或域名不可达")
                                    .font(AppFont.footnote)
                                    .foregroundStyle(.secondary)
                                    .padding()
                            }
                        }
                } else {
                    Text("没有可打开的地址")
                        .font(AppFont.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(sourceName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                if let url = url {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Image(systemName: "safari")
                        }
                    }
                }
            }
        }
    }
}

struct WebPage: UIViewRepresentable {
    let url: URL
    @Binding var loading: Bool
    @Binding var failed: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let parent: WebPage

        init(_ parent: WebPage) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.loading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.loading = false
            parent.failed = true
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.loading = false
            parent.failed = true
        }
    }
}