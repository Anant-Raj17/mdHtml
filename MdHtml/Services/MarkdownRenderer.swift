import Foundation
import Markdown

enum MarkdownRenderer {
    static func renderHTML(from markdown: String, baseURL: URL) -> String {
        let document = Document(parsing: markdown)
        var renderer = HTMLMarkupRenderer()
        let body = renderer.visit(document)
        let css = previewCSS

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <base href="\(baseURL.absoluteString)/">
          <style>\(css)</style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    private static var previewCSS: String {
        if let url = Bundle.main.url(forResource: "PreviewStyles", withExtension: "css"),
           let css = try? String(contentsOf: url, encoding: .utf8) {
            return css
        }

        return """
        body { font: -apple-system-body; line-height: 1.5; margin: 24px; color: #1d1d1f; }
        h1,h2,h3,h4,h5,h6 { line-height: 1.2; margin-top: 1.4em; margin-bottom: 0.5em; }
        pre { background: #f5f5f7; padding: 12px; overflow-x: auto; border-radius: 6px; }
        code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 0.92em; }
        img { max-width: 100%; height: auto; }
        blockquote { border-left: 3px solid #d2d2d7; margin-left: 0; padding-left: 12px; color: #515154; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #d2d2d7; padding: 6px 10px; text-align: left; }
        """
    }
}

private struct HTMLMarkupRenderer: MarkupVisitor {
    mutating func defaultVisit(_ markup: Markup) -> String {
        visitChildren(of: markup)
    }

    mutating func visitChildren(of markup: Markup) -> String {
        markup.children.map { visit($0) }.joined()
    }

    mutating func visitText(_ text: Text) -> String {
        escapeHTML(text.plainText)
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String {
        "\n"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String {
        "<br>"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        "<p>\(visitChildren(of: paragraph))</p>"
    }

    mutating func visitHeading(_ heading: Heading) -> String {
        let level = min(max(heading.level, 1), 6)
        return "<h\(level)>\(visitChildren(of: heading))</h\(level)>"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        "<blockquote>\(visitChildren(of: blockQuote))</blockquote>"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        let language = codeBlock.language ?? ""
        let code = escapeHTML(codeBlock.code)
        if language.isEmpty {
            return "<pre><code>\(code)</code></pre>"
        }
        return "<pre><code class=\"language-\(escapeHTML(language))\">\(code)</code></pre>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        "<code>\(escapeHTML(inlineCode.code))</code>"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        "<em>\(visitChildren(of: emphasis))</em>"
    }

    mutating func visitStrong(_ strong: Strong) -> String {
        "<strong>\(visitChildren(of: strong))</strong>"
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> String {
        "<del>\(visitChildren(of: strikethrough))</del>"
    }

    mutating func visitLink(_ link: Link) -> String {
        let destination = escapeHTML(link.destination ?? "")
        return "<a href=\"\(destination)\">\(visitChildren(of: link))</a>"
    }

    mutating func visitImage(_ image: Image) -> String {
        let source = escapeHTML(image.source ?? "")
        let alt = escapeHTML(image.plainText)
        return "<img src=\"\(source)\" alt=\"\(alt)\">"
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> String {
        "<ul>\(visitChildren(of: unorderedList))</ul>"
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) -> String {
        "<ol>\(visitChildren(of: orderedList))</ol>"
    }

    mutating func visitListItem(_ listItem: ListItem) -> String {
        "<li>\(visitChildren(of: listItem))</li>"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
        "<hr>"
    }

    mutating func visitTable(_ table: Table) -> String {
        var html = "<table><thead><tr>"
        for cell in table.head.cells {
            html += "<th>\(visitChildren(of: cell))</th>"
        }
        html += "</tr></thead><tbody>"

        for row in table.body.rows {
            html += renderTableRowHTML(row)
        }

        html += "</tbody></table>"
        return html
    }

    private mutating func renderTableRowHTML(_ row: Table.Row) -> String {
        var html = "<tr>"
        for cell in row.cells {
            html += "<td>\(visitChildren(of: cell))</td>"
        }
        html += "</tr>"
        return html
    }

    private func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
