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
                List(selection: Binding<URL?>(
                    get: { appModel.selectedFile?.id },
                    set: { id in
                        let file = appModel.files.first(where: { $0.id == id })
                        appModel.selectFile(file)
                    }
                )) {
                    SidebarFolderContent(node: appModel.fileTree)
                }
            }
        }
        .frame(minWidth: 220)
    }
}

private struct SidebarFolderContent: View {
    let node: FolderNode

    var body: some View {
        ForEach(node.folders) { folder in
            DisclosureGroup {
                SidebarFolderContent(node: folder)
            } label: {
                Label(folder.name, systemImage: "folder.fill")
            }
        }

        ForEach(node.files) { file in
            Label {
                Text(file.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } icon: {
                Image(systemName: file.kind == .markdown ? "doc.richtext" : "globe")
            }
            .tag(file.id)
        }
    }
}
