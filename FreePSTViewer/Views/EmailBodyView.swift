import SwiftUI
import WebKit
@preconcurrency import PstReader

struct EmailBodyView: View {
    let message: PstFile.Message
    var attachments: [PstFile.Attachment] = []

    var body: some View {
        if message.isContact {
            ContactBodyView(message: message)
        } else if let html = message.bodyHtmlString {
            HTMLEmailView(
                html: html,
                attachments: attachments
            )
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
    var attachments: [PstFile.Attachment] = []

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = false
        config.defaultWebpagePreferences = prefs

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        // Block all remote network loads
        WKContentRuleListStore.default()?.compileContentRuleList(
            forIdentifier: "block-remote",
            encodedContentRuleList: """
            [{"trigger":{"url-filter":".*"},\
            "action":{"type":"block"}}]
            """
        ) { ruleList, _ in
            if let ruleList = ruleList {
                webView.configuration.userContentController
                    .add(ruleList)
            }
            webView.loadHTMLString(
                self.wrappedHTML, baseURL: nil
            )
        }

        return webView
    }

    func updateNSView(
        _ webView: WKWebView,
        context: Context
    ) {
        if context.coordinator.currentHTML != html {
            context.coordinator.currentHTML = html
            webView.loadHTMLString(wrappedHTML, baseURL: nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(html: html)
    }

    /// Resolves cid: references in HTML to data: URIs using
    /// inline attachment data.
    private var resolvedHTML: String {
        var result = sanitizeHTML(html)
        for attachment in attachments {
            guard let contentId = attachment.attachContentId,
                  !contentId.isEmpty,
                  let data = attachment.fileData
            else { continue }
            let mime = attachment.mimeType ?? "application/octet-stream"
            let base64 = data.base64EncodedString()
            let dataURI = "data:\(mime);base64,\(base64)"
            result = result.replacingOccurrences(
                of: "cid:\(contentId)",
                with: dataURI
            )
        }
        return result
    }

    /// Strips inline event handlers and javascript: URIs from
    /// HTML to mitigate XSS risks beyond allowsContentJavaScript.
    private func sanitizeHTML(_ html: String) -> String {
        var result = html
        // Remove inline event handlers (onclick, onerror, onload, etc.)
        if let eventRegex = try? NSRegularExpression(
            pattern: "\\s+on\\w+\\s*=\\s*(\"[^\"]*\"|'[^']*'|[^\\s>]+)",
            options: .caseInsensitive
        ) {
            result = eventRegex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }
        // Remove javascript: URIs in href/src/action attributes
        if let jsRegex = try? NSRegularExpression(
            pattern: "(href|src|action)\\s*=\\s*([\"'])\\s*javascript:",
            options: .caseInsensitive
        ) {
            result = jsRegex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1=$2#blocked:"
            )
        }
        return result
    }

    /// Wrap the email HTML in a minimal document with safe defaults.
    private var wrappedHTML: String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" \
        content="width=device-width, initial-scale=1">
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
        \(resolvedHTML)
        </body>
        </html>
        """
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var currentHTML: String

        init(html: String) {
            self.currentHTML = html
        }

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
