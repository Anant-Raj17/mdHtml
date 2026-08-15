import SwiftUI

struct PreviewPane: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Group {
            if let file = appModel.selectedFile {
                if file.kind == .markdown, appModel.isEditingMarkdown {
                    MarkdownEditorView(text: Binding(
                        get: { appModel.markdownDraft },
                        set: { appModel.updateDraft($0) }
                    ))
                } else if file.kind == .markdown {
                    // Avoid WKWebView for markdown — sandbox/XPC was leaving a blank pane
                    // even after HTML was successfully written to disk.
                    NativeMarkdownPreview(source: appModel.markdownDraft)
                        .id(file.id)
                } else {
                    WebPreviewView(file: file, markdownSource: appModel.markdownDraft)
                        .id(file.id)
                }
            } else {
                ContentUnavailableView {
                    Label("Select a File", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("Choose a Markdown or HTML file from the sidebar.")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle(appModel.windowTitle)
    }
}
