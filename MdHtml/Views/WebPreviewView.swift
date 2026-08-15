import AppKit
import SwiftUI
import WebKit

struct WebPreviewView: View {
    let file: FileItem
    let markdownSource: String

    var body: some View {
        WebPreviewRepresentable(file: file, markdownSource: markdownSource)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Container so WKWebView always receives a non-zero layout frame from SwiftUI.
private final class WebViewHost: NSView {
    let webView: WKWebView

    init(webView: WKWebView) {
        self.webView = webView
        super.init(frame: .zero)
        wantsLayer = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct WebPreviewRepresentable: NSViewRepresentable {
    let file: FileItem
    let markdownSource: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WebViewHost {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(true, forKey: "drawsBackground")
        webView.underPageBackgroundColor = NSColor.textBackgroundColor

        context.coordinator.loadedToken = nil
        context.coordinator.webView = webView

        return WebViewHost(webView: webView)
    }

    func updateNSView(_ host: WebViewHost, context: Context) {
        context.coordinator.webView = host.webView
        context.coordinator.loadIfNeeded(
            file: file,
            markdownSource: markdownSource,
            into: host.webView
        )
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedToken: String?
        weak var webView: WKWebView?

        private let previewRoot: URL = {
            let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let url = base.appendingPathComponent("MdHtmlPreviews", isDirectory: true)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }()

        func loadIfNeeded(file: FileItem, markdownSource: String, into webView: WKWebView) {
            let token: String
            switch file.kind {
            case .html:
                token = "html:\(file.url.path)"
            case .markdown:
                token = "md:\(file.url.path):\(markdownSource.hashValue)"
            }

            guard loadedToken != token else { return }
            loadedToken = token

            switch file.kind {
            case .html:
                let folderURL = file.url.deletingLastPathComponent()
                webView.loadFileURL(file.url, allowingReadAccessTo: folderURL)
            case .markdown:
                let html = MarkdownRenderer.renderHTML(from: markdownSource, baseURL: nil)
                if let previewURL = writePreviewHTML(html, for: file) {
                    webView.loadFileURL(previewURL, allowingReadAccessTo: previewRoot)
                } else {
                    webView.loadHTMLString(html, baseURL: nil)
                }
            }
        }

        private func writePreviewHTML(_ html: String, for file: FileItem) -> URL? {
            let digest = file.url.path.data(using: .utf8)?
                .base64EncodedString()
                .replacingOccurrences(of: "/", with: "_")
                .prefix(80) ?? "preview"
            let previewURL = previewRoot.appendingPathComponent("\(digest).html")
            do {
                try html.write(to: previewURL, atomically: true, encoding: .utf8)
                return previewURL
            } catch {
                return nil
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            loadedToken = nil
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            loadedToken = nil
        }
    }
}
