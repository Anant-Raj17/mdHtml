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

    init(url: URL, rootURL: URL) {
        self.url = url
        self.id = url
        self.kind = FileKind(url: url)!
        self.relativePath = url.path.replacingOccurrences(of: rootURL.path + "/", with: "")
    }
}
