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
        .id("\(file.url.path)-\(source.hashValue)")
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

    func makeNSView(context: Context) -> WKWebView {
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
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onRequestAddComment = onRequestAddComment
        context.coordinator.onRemoveComment = onRemoveComment

        let token = "\(file.url.path)::\(source.hashValue)"
        guard context.coordinator.loadedToken != token else { return }
        context.coordinator.loadedToken = token

        let folderURL = file.url.deletingLastPathComponent()
        switch file.kind {
        case .html:
            let html = preparedHTML(from: source, baseURL: folderURL)
            webView.loadHTMLString(html, baseURL: folderURL)
        case .markdown:
            let html = MarkdownRenderer.renderHTML(from: source, baseURL: folderURL)
            webView.loadHTMLString(html, baseURL: folderURL)
        }
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "mdhtml")
    }

    private func preparedHTML(from html: String, baseURL: URL) -> String {
        var output = CommentMarkup.replaceCommentsWithBoxes(in: html)
        if output.range(of: "<base", options: .caseInsensitive) == nil {
            let baseTag = "<base href=\"\(baseURL.absoluteString)\">"
            if let headRange = output.range(of: "<head", options: .caseInsensitive),
               let tagEnd = output[headRange.lowerBound...].range(of: ">") {
                output.insert(contentsOf: baseTag, at: tagEnd.upperBound)
            } else {
                output = "<head>\(baseTag)</head>" + output
            }
        }
        return output
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var onRequestAddComment: (CommentAnchor) -> Void
        var onRemoveComment: (String, Int?) -> Void
        var loadedToken = ""
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
