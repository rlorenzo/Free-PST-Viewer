import SwiftUI
import WebKit
@preconcurrency import PstReader

struct EmailBodyView: View {
    let message: PstFile.Message

    var body: some View {
        if let html = message.bodyHtmlString {
            HTMLEmailView(html: html)
        } else if let text = message.bodyText {
            ScrollView {
                Text(text)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text("No content available")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct HTMLEmailView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = false
        config.defaultWebpagePreferences = prefs

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        // Block all remote network loads (tracking pixels, remote images, external resources)
        WKContentRuleListStore.default()?.compileContentRuleList(
            forIdentifier: "block-remote",
            encodedContentRuleList: """
            [{"trigger":{"url-filter":".*"},"action":{"type":"block"}}]
            """
        ) { ruleList, _ in
            if let ruleList = ruleList {
                webView.configuration.userContentController.add(ruleList)
            }
            webView.loadHTMLString(self.wrappedHTML, baseURL: nil)
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Reload when html content changes
        if context.coordinator.currentHTML != html {
            context.coordinator.currentHTML = html
            webView.loadHTMLString(wrappedHTML, baseURL: nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(html: html)
    }

    /// Wrap the email HTML in a minimal document with safe defaults.
    private var wrappedHTML: String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            font-size: 13px;
            line-height: 1.5;
            color: #333;
            padding: 0;
            margin: 0;
            word-wrap: break-word;
            overflow-wrap: break-word;
        }
        img { max-width: 100%; height: auto; }
        @media (prefers-color-scheme: dark) {
            body { color: #ddd; background-color: #1e1e1e; }
            a { color: #58a6ff; }
        }
        </style>
        </head>
        <body>
        \(html)
        </body>
        </html>
        """
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var currentHTML: String

        init(html: String) {
            self.currentHTML = html
        }

        // Open clicked links in the system browser instead of navigating
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}
