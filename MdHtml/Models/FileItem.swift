import Foundation

enum FileKind: Equatable {
    case markdown
    case html

    init?(url: URL) {
        switch url.pathExtension.lowercased() {
        case "md", "markdown":
            self = .markdown
        case "html", "htm":
            self = .html
        default:
            return nil
        }
    }

    var displayName: String {
        switch self {
        case .markdown:
            return "Markdown"
        case .html:
            return "HTML"
        }
    }
}

struct FileItem: Identifiable, Hashable {
    let id: URL
    let url: URL
    let kind: FileKind
    let relativePath: String

    var name: String {
        url.lastPathComponent
    }

    var pathComponents: [String] {
        relativePath.split(separator: "/").map(String.init)
    }

    init(url: URL, rootURL: URL) {
        let standardizedURL = url.standardizedFileURL
        let standardizedRoot = rootURL.standardizedFileURL

        self.url = standardizedURL
        self.id = standardizedURL
        self.kind = FileKind(url: standardizedURL)!

        let rootPath = standardizedRoot.path
        let filePath = standardizedURL.path
        if filePath.hasPrefix(rootPath + "/") {
            self.relativePath = String(filePath.dropFirst(rootPath.count + 1))
        } else {
            self.relativePath = standardizedURL.lastPathComponent
        }
    }
}

struct FolderNode: Identifiable, Hashable {
    let id: String
    let name: String
    var folders: [FolderNode]
    var files: [FileItem]

    var isEmpty: Bool {
        folders.isEmpty && files.isEmpty
    }

    static func buildTree(from files: [FileItem]) -> FolderNode {
        var root = FolderNode(id: "", name: "", folders: [], files: [])

        for file in files {
            let components = file.pathComponents
            guard !components.isEmpty else { continue }

            if components.count == 1 {
                root.files.append(file)
                continue
            }

            insert(file, path: Array(components.dropLast()), into: &root)
        }

        root.sortRecursively()
        return root
    }

    private static func insert(_ file: FileItem, path: [String], into node: inout FolderNode) {
        guard let folderName = path.first else {
            node.files.append(file)
            return
        }

        let folderID = node.id.isEmpty ? folderName : "\(node.id)/\(folderName)"
        if let index = node.folders.firstIndex(where: { $0.id == folderID }) {
            insert(file, path: Array(path.dropFirst()), into: &node.folders[index])
            return
        }

        var folder = FolderNode(id: folderID, name: folderName, folders: [], files: [])
        insert(file, path: Array(path.dropFirst()), into: &folder)
        node.folders.append(folder)
    }

    private mutating func sortRecursively() {
        folders.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        files.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        for index in folders.indices {
            folders[index].sortRecursively()
        }
    }
}
