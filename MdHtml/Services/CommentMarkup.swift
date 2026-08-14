import Foundation

struct CommentAnchor: Equatable {
    var selectedText: String
    var prefix: String
    var suffix: String
    var blockText: String
    var srcLine: Int?
    var srcColumn: Int?
    var srcEndLine: Int?
    var srcEndColumn: Int?
    var existingComment: String
    var clickX: Double
    var clickY: Double

    init(messageBody: Any) {
        let dict = messageBody as? [String: Any] ?? [:]
        selectedText = dict["selectedText"] as? String ?? ""
        prefix = dict["prefix"] as? String ?? ""
        suffix = dict["suffix"] as? String ?? ""
        blockText = dict["blockText"] as? String ?? ""
        srcLine = Self.intValue(dict["srcLine"])
        srcColumn = Self.intValue(dict["srcColumn"])
        srcEndLine = Self.intValue(dict["srcEndLine"])
        srcEndColumn = Self.intValue(dict["srcEndColumn"])
        existingComment = dict["existingComment"] as? String ?? ""
        clickX = (dict["x"] as? NSNumber)?.doubleValue ?? 0
        clickY = (dict["y"] as? NSNumber)?.doubleValue ?? 0
    }

    private static func intValue(_ value: Any?) -> Int? {
        if value is NSNull { return nil }
        if let number = value as? Int { return number }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }
}

enum CommentMarkup {
    static let marker = "@mdhtml"

    static func encode(_ text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "-->", with: "→")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "<!-- @mdhtml: \(cleaned) -->"
    }

    static func decode(fromHTML html: String) -> String? {
        guard let regex = commentRegex else { return nil }
        let ns = html as NSString
        guard let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges > 1,
              let textRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        let text = String(html[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    static func replaceCommentsWithBoxes(in source: String) -> String {
        guard let regex = commentRegex else { return source }
        let nsSource = source as NSString
        let matches = regex.matches(in: source, range: NSRange(location: 0, length: nsSource.length))
        var result = source
        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: source),
                  let textRange = Range(match.range(at: 1), in: source) else {
                continue
            }
            let text = String(source[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let block = isStandaloneLine(fullRange, in: source)
            result.replaceSubrange(fullRange, with: boxHTML(text: text, block: block))
        }
        return result
    }

    static func boxHTML(text: String, block: Bool) -> String {
        let tag = block ? "aside" : "span"
        return "<\(tag) class=\"mdhtml-comment\" data-mdhtml-comment=\"1\" data-text=\"\(escapeAttribute(text))\"><span class=\"mdhtml-comment-kicker\">Note</span>\(escapeHTML(text))</\(tag)>"
    }

    static func insert(comment text: String, into source: String, kind: FileKind, anchor: CommentAnchor) -> String {
        let markup = encode(text)
        guard markup != encode("") else { return source }

        if !anchor.selectedText.isEmpty,
           let range = findOccurrence(anchor.selectedText, in: source, nearLine: anchor.srcLine) {
            return insert(markup, in: source, at: range.upperBound, block: false)
        }

        if kind == .html || kind == .markdown,
           !anchor.prefix.isEmpty,
           let index = findPrefixSuffix(prefix: anchor.prefix, suffix: anchor.suffix, in: source, nearLine: anchor.srcLine) {
            return insert(markup, in: source, at: index, block: false)
        }

        if let endLine = anchor.srcEndLine,
           let endColumn = anchor.srcEndColumn,
           let index = utf8Index(in: source, line: endLine, column: endColumn) {
            return insert(markup, in: source, at: index, block: true)
        }

        if !anchor.blockText.isEmpty,
           let range = findOccurrence(anchor.blockText, in: source, nearLine: anchor.srcLine) {
            return insert(markup, in: source, at: range.upperBound, block: true)
        }

        return appendFallback(markup, to: source, kind: kind)
    }

    static func remove(comment text: String, from source: String, nearLine: Int?) -> String {
        let encoded = encode(text)
        guard let range = findOccurrence(encoded, in: source, nearLine: nearLine) else {
            return source
        }

        var result = source
        var removal = range

        if removal.lowerBound > result.startIndex {
            let before = result.index(before: removal.lowerBound)
            if result[before] == " " {
                removal = before..<removal.upperBound
            }
        }
        if removal.upperBound < result.endIndex, result[removal.upperBound] == " " {
            removal = removal.lowerBound..<result.index(after: removal.upperBound)
        }

        result.removeSubrange(removal)
        return result
    }

    static let previewCSS = """
    .mdhtml-comment {
      display: inline-block;
      vertical-align: middle;
      font: 11px/1.35 -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
      padding: 3px 7px;
      margin: 1px 4px;
      border: 1px solid;
      border-radius: 2px;
      max-width: 22rem;
      white-space: pre-wrap;
      box-shadow: none;
    }
    aside.mdhtml-comment {
      display: block;
      width: fit-content;
      max-width: 100%;
      margin: 8px 0;
    }
    .mdhtml-comment-kicker {
      display: inline-block;
      font-size: 9px;
      font-weight: 700;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      margin-right: 6px;
      opacity: 0.7;
    }
    @media (prefers-color-scheme: light) {
      .mdhtml-comment {
        background: #f3f1ea;
        border-color: #c4c0b4;
        color: #3a382f;
      }
    }
    @media (prefers-color-scheme: dark) {
      .mdhtml-comment {
        background: #2c2c2e;
        border-color: #636366;
        color: #eceae3;
      }
    }
    """

    static let contextMenuScript = """
    (function() {
      if (window.__mdhtmlCommentsInstalled) return;
      window.__mdhtmlCommentsInstalled = true;

      if (!document.getElementById('mdhtml-comment-style')) {
        var style = document.createElement('style');
        style.id = 'mdhtml-comment-style';
        style.textContent = `\(previewCSS)`;
        document.documentElement.appendChild(style);
      }

      document.addEventListener('contextmenu', function(e) {
        e.preventDefault();
        var selectedText = window.getSelection ? String(window.getSelection()) : '';
        var node = e.target;
        if (node && node.nodeType !== 1) node = node.parentElement;
        var commentEl = node && node.closest ? node.closest('.mdhtml-comment') : null;
        var prefix = '';
        var suffix = '';
        var range = null;
        if (document.caretRangeFromPoint) {
          range = document.caretRangeFromPoint(e.clientX, e.clientY);
        } else if (document.caretPositionFromPoint) {
          var pos = document.caretPositionFromPoint(e.clientX, e.clientY);
          if (pos) {
            range = document.createRange();
            range.setStart(pos.offsetNode, pos.offset);
          }
        }
        if (range && range.startContainer && range.startContainer.nodeType === 3) {
          var text = range.startContainer.textContent || '';
          var offset = range.startOffset;
          prefix = text.slice(Math.max(0, offset - 48), offset);
          suffix = text.slice(offset, offset + 48);
        }
        var block = node && node.closest ? node.closest('[data-src-end-line], p, h1, h2, h3, h4, h5, h6, li, pre, blockquote, td, .note') : null;
        function num(el, name) {
          if (!el) return null;
          var value = el.getAttribute(name);
          if (value === null || value === '') return null;
          var parsed = parseInt(value, 10);
          return isNaN(parsed) ? null : parsed;
        }
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.mdhtml) {
          window.webkit.messageHandlers.mdhtml.postMessage({
            selectedText: selectedText,
            prefix: prefix,
            suffix: suffix,
            blockText: block ? String(block.innerText || '').trim().slice(0, 120) : '',
            srcLine: num(block, 'data-src-line'),
            srcColumn: num(block, 'data-src-column'),
            srcEndLine: num(block, 'data-src-end-line'),
            srcEndColumn: num(block, 'data-src-end-column'),
            existingComment: commentEl ? (commentEl.getAttribute('data-text') || '') : '',
            x: e.clientX,
            y: e.clientY
          });
        }
      }, true);
    })();
    """

    private static let commentRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"<!--\s*@mdhtml:\s*((?:(?!-->).)*?)\s*-->"#
    )

    private static func isStandaloneLine(_ range: Range<String.Index>, in source: String) -> Bool {
        let lineStart = source[..<range.lowerBound].lastIndex(of: "\n").map { source.index(after: $0) } ?? source.startIndex
        let lineEnd = source[range.upperBound...].firstIndex(of: "\n") ?? source.endIndex
        let leading = source[lineStart..<range.lowerBound]
        let trailing = source[range.upperBound..<lineEnd]
        return leading.allSatisfy(\.isWhitespace) && trailing.allSatisfy(\.isWhitespace)
    }

    private static func insert(_ markup: String, in source: String, at index: String.Index, block: Bool) -> String {
        var insertion = markup
        if block {
            let needsLeadingBreak = index > source.startIndex && source[source.index(before: index)] != "\n"
            let needsTrailingBreak = index < source.endIndex && source[index] != "\n"
            insertion = (needsLeadingBreak ? "\n" : "") + markup + (needsTrailingBreak ? "\n" : "\n")
        } else {
            let needsLeadingSpace = index > source.startIndex && !source[source.index(before: index)].isWhitespace
            insertion = (needsLeadingSpace ? " " : "") + markup
        }
        var result = source
        result.insert(contentsOf: insertion, at: index)
        return result
    }

    private static func appendFallback(_ markup: String, to source: String, kind: FileKind) -> String {
        if kind == .html, let range = source.range(of: "</body>", options: [.caseInsensitive, .backwards]) {
            return source.replacingCharacters(in: range, with: "\n" + markup + "\n</body>")
        }
        if source.hasSuffix("\n") {
            return source + markup + "\n"
        }
        return source + "\n" + markup + "\n"
    }

    private static func findPrefixSuffix(prefix: String, suffix: String, in source: String, nearLine: Int?) -> String.Index? {
        let combined = prefix + suffix
        if !combined.isEmpty, let range = findOccurrence(combined, in: source, nearLine: nearLine) {
            return source.index(range.lowerBound, offsetBy: prefix.count)
        }
        if !prefix.isEmpty, let range = findOccurrence(prefix, in: source, nearLine: nearLine) {
            return range.upperBound
        }
        return nil
    }

    private static func findOccurrence(_ needle: String, in source: String, nearLine: Int?) -> Range<String.Index>? {
        let trimmed = needle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var matches: [Range<String.Index>] = []
        var searchStart = source.startIndex
        while let range = source.range(of: trimmed, range: searchStart..<source.endIndex) {
            matches.append(range)
            searchStart = range.upperBound
        }

        if matches.isEmpty, trimmed.contains(where: \.isWhitespace) {
            return findCollapsedWhitespace(trimmed, in: source)
        }

        guard let nearLine, matches.count > 1 else {
            return matches.first
        }

        return matches.min { lhs, rhs in
            abs(lineNumber(of: lhs.lowerBound, in: source) - nearLine) < abs(lineNumber(of: rhs.lowerBound, in: source) - nearLine)
        }
    }

    private static func findCollapsedWhitespace(_ needle: String, in source: String) -> Range<String.Index>? {
        let compactNeedle = needle.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let compactSource = source.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard compactSource.contains(compactNeedle) else { return nil }
        let firstWord = needle.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? needle
        return source.range(of: firstWord)
    }

    static func utf8Index(in source: String, line: Int, column: Int) -> String.Index? {
        guard line > 0, column > 0 else { return nil }

        var currentLine = 1
        var lineStart = source.startIndex
        while currentLine < line {
            guard let newline = source[lineStart...].firstIndex(of: "\n") else { return source.endIndex }
            lineStart = source.index(after: newline)
            currentLine += 1
        }

        let utf8 = source.utf8
        guard let utf8LineStart = lineStart.samePosition(in: utf8) else { return lineStart }
        let offset = column - 1
        guard let utf8Target = utf8.index(utf8LineStart, offsetBy: offset, limitedBy: utf8.endIndex) else {
            return source.endIndex
        }
        return String.Index(utf8Target, within: source) ?? source.endIndex
    }

    private static func lineNumber(of index: String.Index, in source: String) -> Int {
        1 + source[source.startIndex..<index].filter { $0 == "\n" }.count
    }

    static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func escapeAttribute(_ value: String) -> String {
        escapeHTML(value)
    }
}
