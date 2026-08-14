import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        Group {
            if appModel.files.isEmpty {
                ContentUnavailableView {
                    Label("No Files", systemImage: "doc.text")
                } description: {
                    Text("Open a folder containing Markdown or HTML files.")
                } actions: {
                    Button("Open Folder") {
                        appModel.openFolderPanel()
                    }
                }
            } else {
                List(appModel.files, selection: Binding(
                    get: { appModel.selectedFile },
                    set: { appModel.selectFile($0) }
                )) { file in
                    Label {
                        Text(file.relativePath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } icon: {
                        Image(systemName: file.kind == .markdown ? "doc.richtext" : "globe")
                    }
                    .tag(file)
                }
            }
        }
        .frame(minWidth: 220)
    }
}
