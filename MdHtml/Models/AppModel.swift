import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var folderURL: URL?
    @Published private(set) var files: [FileItem] = []
    @Published private(set) var fileTree: FolderNode = FolderNode(id: "", name: "", folders: [], files: [])
    @Published var selectedFile: FileItem?
    @Published var isEditingMarkdown = false
    @Published var markdownDraft = ""
    @Published var isDirty = false
    @Published var showUnsavedAlert = false
    @Published var pendingSelection: FileItem?

    private var folderAccessActive = false

    init() {
        if let restored = BookmarkStore.restoreBookmarkedURL() {
            openFolder(restored, persistBookmark: false)
        }
    }

    var canEditCurrentFile: Bool {
        selectedFile?.kind == .markdown
    }

    var windowTitle: String {
        guard let selectedFile else {
            return folderURL == nil ? "MdHtml" : "MdHtml"
        }

        let name = selectedFile.url.lastPathComponent
        return isDirty ? "\(name) — Edited" : name
    }

    func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        openFolder(url, persistBookmark: true)
    }

    func openFolder(_ url: URL, persistBookmark: Bool) {
        stopFolderAccess()

        // Security-scoped access is required in the sandbox after Open panel /
        // bookmark restore. Don't abort if the call returns false for an
        // already-accessible path — still attempt to list files.
        folderAccessActive = url.startAccessingSecurityScopedResource()
        folderURL = url
        files = FolderBrowser.listSupportedFiles(in: url)
        fileTree = FolderNode.buildTree(from: files)

        if persistBookmark {
            BookmarkStore.saveBookmark(for: url)
        }

        if let selected = selectedFile,
           let match = files.first(where: { $0.url == selected.url }) {
            selectedFile = match
            reloadCurrentFileContent()
        } else {
            selectedFile = preferredInitialSelection()
            isEditingMarkdown = false
            isDirty = false
            reloadCurrentFileContent()
        }
    }

    private func preferredInitialSelection() -> FileItem? {
        files.first(where: { $0.kind == .markdown }) ?? files.first
    }

    func selectFile(_ file: FileItem?) {
        guard file?.url != selectedFile?.url else { return }

        if isDirty {
            pendingSelection = file
            showUnsavedAlert = true
            return
        }

        applySelection(file)
    }

    func applySelection(_ file: FileItem?) {
        selectedFile = file
        isEditingMarkdown = false
        isDirty = false
        reloadCurrentFileContent()
    }

    func beginEditing() {
        guard canEditCurrentFile, !isEditingMarkdown else { return }
        reloadCurrentFileContent()
        isEditingMarkdown = true
    }

    func finishEditing() {
        guard isEditingMarkdown else { return }
        if isDirty {
            pendingSelection = selectedFile
            showUnsavedAlert = true
            return
        }
        isEditingMarkdown = false
    }

    func saveMarkdown() {
        guard let file = selectedFile, file.kind == .markdown else { return }

        do {
            try markdownDraft.write(to: file.url, atomically: true, encoding: .utf8)
            isDirty = false
        } catch {
            presentError("Could not save file.", error: error)
        }
    }

    func discardChangesAndContinue() {
        showUnsavedAlert = false
        isDirty = false

        if pendingSelection?.url == selectedFile?.url {
            isEditingMarkdown = false
            reloadCurrentFileContent()
        } else {
            applySelection(pendingSelection)
        }

        pendingSelection = nil
    }

    func saveChangesAndContinue() {
        saveMarkdown()
        showUnsavedAlert = false

        if pendingSelection?.url == selectedFile?.url {
            isEditingMarkdown = false
            reloadCurrentFileContent()
        } else {
            applySelection(pendingSelection)
        }

        pendingSelection = nil
    }

    func cancelPendingSelectionChange() {
        showUnsavedAlert = false
        pendingSelection = nil
    }

    func updateDraft(_ text: String) {
        markdownDraft = text
        isDirty = true
    }

    func reloadCurrentFileContent() {
        guard let file = selectedFile, file.kind == .markdown else {
            markdownDraft = ""
            return
        }

        do {
            markdownDraft = try String(contentsOf: file.url, encoding: .utf8)
            isDirty = false
        } catch {
            markdownDraft = ""
            presentError("Could not read file.", error: error)
        }
    }

    private func stopFolderAccess() {
        if folderAccessActive, let folderURL {
            folderURL.stopAccessingSecurityScopedResource()
        }
        folderAccessActive = false
    }

    private func presentError(_ message: String, error: Error) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}
