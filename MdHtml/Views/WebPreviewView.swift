import SwiftUI
import WebKit

struct WebPreviewView: View {
    let file: FileItem
    let markdownSource: String

    var body: some View {
        WebPreviewRepresentable(file: file, markdownSource: markdownSource)
            .id(previewID)
    }

    private var previewID: String {
        switch file.kind {
        case .html:
            return "html-\(file.url.path)"
        case .markdown:
            return "md-\(file.url.path)-\(markdownSource.hashValue)"
        }
    }
}

private struct WebPreviewRepresentable: NSViewRepresentable {
    let file: FileItem
    let markdownSource: String

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        switch file.kind {
        case .html:
            let folderURL = file.url.deletingLastPathComponent()
            webView.loadFileURL(file.url, allowingReadAccessTo: folderURL)
        case .markdown:
            let html = MarkdownRenderer.renderHTML(from: markdownSource, baseURL: file.url.deletingLastPathComponent())
            webView.loadHTMLString(html, baseURL: file.url.deletingLastPathComponent())
        }
    }
}
