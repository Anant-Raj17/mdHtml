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
                    WebPreviewView(file: file, source: appModel.previewSource)
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
        .navigationTitle(appModel.windowTitle)
    }
}
