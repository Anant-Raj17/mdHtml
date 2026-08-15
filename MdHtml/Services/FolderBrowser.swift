import Foundation

enum FolderBrowser {
    static func listSupportedFiles(in folderURL: URL) -> [FileItem] {
        let rootURL = folderURL.standardizedFileURL
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .nameKey]
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var items: [FileItem] = []

        for case let fileURL as URL in enumerator {
            let standardized = fileURL.standardizedFileURL

            // Skip generated preview output.
            if standardized.lastPathComponent == ".mdhtml-preview" {
                enumerator.skipDescendants()
                continue
            }
            if standardized.pathComponents.contains(".mdhtml-preview") {
                continue
            }

            guard let values = try? standardized.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  FileKind(url: standardized) != nil else {
                continue
            }

            items.append(FileItem(url: standardized, rootURL: rootURL))
        }

        return items.sorted { $0.relativePath.localizedCaseInsensitiveCompare($1.relativePath) == .orderedAscending }
    }
}
