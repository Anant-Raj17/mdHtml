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
                } else {
                    // WebKit preview keeps right-click comments working for md/html.
                    // Loading/layout fixes in WebPreviewView address the blank-pane bug.
                    WebPreviewView(file: file, source: appModel.previewSource)
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
