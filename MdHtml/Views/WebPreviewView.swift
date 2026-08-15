import AppKit
import SwiftUI
import WebKit

struct WebPreviewView: View {
    @EnvironmentObject private var appModel: AppModel
    let file: FileItem
    let source: String

    var body: some View {
        WebPreviewRepresentable(
            file: file,
            source: source,
            onRequestAddComment: { appModel.beginAddComment(anchor: $0) },
            onRemoveComment: { text, line in appModel.removeComment(text, nearLine: line) }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id("\(file.url.path)-\(source.hashValue)")
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
    let source: String
    let onRequestAddComment: (CommentAnchor) -> Void
    let onRemoveComment: (String, Int?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onRequestAddComment: onRequestAddComment, onRemoveComment: onRemoveComment)
    }

    func makeNSView(context: Context) -> WebViewHost {
        let userContent = WKUserContentController()
        userContent.add(context.coordinator, name: "mdhtml")
        userContent.addUserScript(WKUserScript(
            source: CommentMarkup.contextMenuScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContent
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(true, forKey: "drawsBackground")
        webView.underPageBackgroundColor = NSColor.textBackgroundColor

        // SwiftUI can recreate the WKWebView while reusing the coordinator.
        context.coordinator.loadedToken = nil
        context.coordinator.webView = webView

        return WebViewHost(webView: webView)
    }

    func updateNSView(_ host: WebViewHost, context: Context) {
        context.coordinator.webView = host.webView
        context.coordinator.onRequestAddComment = onRequestAddComment
        context.coordinator.onRemoveComment = onRemoveComment

        let token = "\(file.url.path)::\(source.hashValue)"
        guard context.coordinator.loadedToken != token else { return }
        context.coordinator.loadedToken = token

        switch file.kind {
        case .html:
            let html = preparedHTML(from: source)
            // Avoid file:// base URLs with loadHTMLString — App Sandbox often blanks the page.
            host.webView.loadHTMLString(html, baseURL: nil)
        case .markdown:
            let html = MarkdownRenderer.renderHTML(from: source, baseURL: nil)
            host.webView.loadHTMLString(html, baseURL: nil)
        }
    }

    static func dismantleNSView(_ nsView: WebViewHost, coordinator: Coordinator) {
        nsView.webView.configuration.userContentController.removeScriptMessageHandler(forName: "mdhtml")
    }

    private func preparedHTML(from html: String) -> String {
        CommentMarkup.replaceCommentsWithBoxes(in: html)
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var onRequestAddComment: (CommentAnchor) -> Void
        var onRemoveComment: (String, Int?) -> Void
        var loadedToken: String?
        weak var webView: WKWebView?
        private var pendingAnchor: CommentAnchor?

        init(
            onRequestAddComment: @escaping (CommentAnchor) -> Void,
            onRemoveComment: @escaping (String, Int?) -> Void
        ) {
            self.onRequestAddComment = onRequestAddComment
            self.onRemoveComment = onRemoveComment
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            let anchor = CommentAnchor(messageBody: message.body)
            DispatchQueue.main.async { [weak self] in
                self?.showMenu(for: anchor)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            loadedToken = nil
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            loadedToken = nil
        }

        private func showMenu(for anchor: CommentAnchor) {
            pendingAnchor = anchor
            guard let webView else { return }

            let menu = NSMenu()
            let addItem = NSMenuItem(title: "Add Comment", action: #selector(addComment), keyEquivalent: "")
            addItem.target = self
            menu.addItem(addItem)

            if !anchor.existingComment.isEmpty {
                let removeItem = NSMenuItem(title: "Remove Comment", action: #selector(removeComment), keyEquivalent: "")
                removeItem.target = self
                menu.addItem(removeItem)
            }

            if !anchor.selectedText.isEmpty {
                menu.addItem(.separator())
                let copyItem = NSMenuItem(title: "Copy", action: #selector(copySelection), keyEquivalent: "")
                copyItem.target = self
                menu.addItem(copyItem)
            }

            let point = NSPoint(x: anchor.clickX, y: webView.bounds.height - anchor.clickY)
            menu.popUp(positioning: nil, at: point, in: webView)
        }

        @objc private func addComment() {
            guard let pendingAnchor else { return }
            onRequestAddComment(pendingAnchor)
        }

        @objc private func removeComment() {
            guard let pendingAnchor else { return }
            onRemoveComment(pendingAnchor.existingComment, pendingAnchor.srcLine)
        }

        @objc private func copySelection() {
            guard let pendingAnchor else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(pendingAnchor.selectedText, forType: .string)
        }
    }
}
