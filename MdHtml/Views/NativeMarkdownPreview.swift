import SwiftUI

/// Renders markdown with Swift's built-in Markdown support (no WKWebView).
struct NativeMarkdownPreview: View {
    let source: String

    var body: some View {
        ScrollView {
            Text(attributedContent)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var attributedContent: AttributedString {
        if source.isEmpty {
            return AttributedString("Empty markdown file.")
        }

        do {
            return try AttributedString(
                markdown: source,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .full
                )
            )
        } catch {
            return AttributedString(source)
        }
    }
}
