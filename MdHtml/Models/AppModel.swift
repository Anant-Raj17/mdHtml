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
    @Published var htmlSource = ""
    @Published var commentDraft = ""
    @Published var showUnsavedAlert = false
    @Published var pendingSelection: FileItem?

    private var folderAccessActive = false
    private var pendingCommentAnchor: CommentAnchor?

    init() {
        if let restored = BookmarkStore.restoreBookmarkedURL() {
            openFolder(restored, persistBookmark: false)
        }
    }

    var previewSource: String {
        switch selectedFile?.kind {
        case .markdown:
            return markdownDraft
        case .html:
            return htmlSource
        case nil:
            return ""
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
        guard let file = selectedFile else {
            markdownDraft = ""
            htmlSource = ""
            return
        }

        do {
            let text = try String(contentsOf: file.url, encoding: .utf8)
            switch file.kind {
            case .markdown:
                markdownDraft = text
                htmlSource = ""
            case .html:
                htmlSource = text
                markdownDraft = ""
            }
            isDirty = false
        } catch {
            markdownDraft = ""
            htmlSource = ""
            presentError("Could not read file.", error: error)
        }
    }

    func beginAddComment(anchor: CommentAnchor) {
        pendingCommentAnchor = anchor
        commentDraft = ""

        let alert = NSAlert()
        alert.messageText = "Add Comment"
        alert.informativeText = "Saved in the file as an HTML comment so agents can read it."
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(string: "")
        field.placeholderString = "Comment"
        field.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            commentDraft = field.stringValue
            submitComment()
        } else {
            cancelAddComment()
        }
    }

    func cancelAddComment() {
        commentDraft = ""
        pendingCommentAnchor = nil
    }

    func submitComment() {
        let text = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let file = selectedFile, let anchor = pendingCommentAnchor else {
            cancelAddComment()
            return
        }

        let updated = CommentMarkup.insert(comment: text, into: currentSource(for: file), kind: file.kind, anchor: anchor)
        writeSource(updated, for: file)
        cancelAddComment()
    }

    func removeComment(_ text: String, nearLine: Int?) {
        guard let file = selectedFile else { return }
        let updated = CommentMarkup.remove(comment: text, from: currentSource(for: file), nearLine: nearLine)
        writeSource(updated, for: file)
    }

    private func currentSource(for file: FileItem) -> String {
        switch file.kind {
        case .markdown:
            return markdownDraft
        case .html:
            return htmlSource
        }
    }

    private func writeSource(_ text: String, for file: FileItem) {
        do {
            try text.write(to: file.url, atomically: true, encoding: .utf8)
            switch file.kind {
            case .markdown:
                markdownDraft = text
            case .html:
                htmlSource = text
            }
            isDirty = false
        } catch {
            presentError("Could not save comment.", error: error)
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
