import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            PreviewPane()
        }
        .navigationTitle(appModel.windowTitle)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Open Folder") {
                    appModel.openFolderPanel()
                }
            }

            if appModel.canEditCurrentFile {
                ToolbarItem(placement: .automatic) {
                    if appModel.isEditingMarkdown {
                        Button("Done") {
                            appModel.finishEditing()
                        }
                    } else {
                        Button("Edit") {
                            appModel.beginEditing()
                        }
                    }
                }

                if appModel.isEditingMarkdown && appModel.isDirty {
                    ToolbarItem(placement: .automatic) {
                        Button("Save") {
                            appModel.saveMarkdown()
                        }
                        .keyboardShortcut("s", modifiers: .command)
                    }
                }
            }
        }
        .alert("Unsaved Changes", isPresented: $appModel.showUnsavedAlert) {
            Button("Save") {
                appModel.saveChangesAndContinue()
            }
            Button("Discard Changes", role: .destructive) {
                appModel.discardChangesAndContinue()
            }
            Button("Cancel", role: .cancel) {
                appModel.cancelPendingSelectionChange()
            }
        } message: {
            Text("You have unsaved markdown changes.")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel())
}
