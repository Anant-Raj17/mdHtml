import Foundation

enum FolderBrowser {
    static func listSupportedFiles(in folderURL: URL) -> [FileItem] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .nameKey]
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var items: [FileItem] = []

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  FileKind(url: fileURL) != nil else {
                continue
            }

            items.append(FileItem(url: fileURL, rootURL: folderURL))
        }

        return items.sorted { $0.relativePath.localizedCaseInsensitiveCompare($1.relativePath) == .orderedAscending }
    }
}
