import Foundation

/// Renders fediverse post `contentHtml` into a Foundation `AttributedString`.
///
/// UI-agnostic on purpose (no SwiftUI/AppKit): it emits only Foundation attributes
/// — `.link` for anchors and `.inlinePresentationIntent` for bold/italic/strike/code —
/// which SwiftUI's `Text(AttributedString)` renders natively (tappable, accent-colored
/// links; platform fonts; dark-mode correct). iOS reuses this verbatim.
///
/// Handles the exact surface FediHome's sanitizer permits (p, br, a, strong/b, em/i,
/// del/s, h1–h6, ul/ol/li, code/pre, blockquote, img, span, div) plus the upstream
/// Mastodon URL-truncation idiom: `<span class="invisible">` text is hidden and
/// `<span class="ellipsis">` gets a trailing "…", so a truncated link reads
/// `example.com/very/long/url…` instead of the raw URL.
///
/// The tokenizer works on **Unicode scalars** (not `Character`s) so a combining mark,
/// ZWJ, or variation selector adjacent to a `<`/`>`/`-` can't fuse into a grapheme that
/// hides tag boundaries.
public enum FediHTML {
    /// Rich rendering for display.
    public static func attributedString(from html: String) -> AttributedString {
        var renderer = Renderer()
        return renderer.render(tokenize(html))
    }

    /// Plain-text projection (accessibility, previews, search).
    public static func plainText(from html: String) -> String {
        String(attributedString(from: html).characters)
    }
}

// MARK: - Tokenizer

private enum Token {
    case text(String)
    case open(String, [String: String])
    case close(String)
}

private func tokenize(_ html: String) -> [Token] {
    var tokens: [Token] = []
    let s = Array(html.unicodeScalars)
    let n = s.count
    var i = 0
    var text = String.UnicodeScalarView()
    func flush() {
        if !text.isEmpty { tokens.append(.text(String(text))); text = String.UnicodeScalarView() }
    }
    // A '<' only begins a tag when followed by a letter, '/', '!', or '?'. This keeps
    // prose like "5 < 3" literal instead of eating "< 3 …>" as a bogus tag.
    func startsTag(_ u: Unicode.Scalar) -> Bool {
        (u >= "a" && u <= "z") || (u >= "A" && u <= "Z") || u == "/" || u == "!" || u == "?"
    }

    while i < n {
        let c = s[i]
        guard c == "<", i + 1 < n, startsTag(s[i + 1]) else {
            text.append(c); i += 1; continue
        }

        // HTML comment <!-- … -->, including the abrupt-close forms <!--> and <!--->.
        if s[i + 1] == "!", i + 3 < n, s[i + 2] == "-", s[i + 3] == "-" {
            var m = i + 4
            while m < n, !(s[m] == ">" && s[m - 1] == "-" && s[m - 2] == "-") { m += 1 }
            i = m < n ? m + 1 : n
            continue
        }

        // Find the closing '>', respecting quoted attribute values.
        var j = i + 1
        var quote: Unicode.Scalar?
        while j < n {
            let d = s[j]
            if let q = quote { if d == q { quote = nil } }
            else if d == "\"" || d == "'" { quote = d }
            else if d == ">" { break }
            j += 1
        }
        if j >= n { text.append(contentsOf: s[i..<n]); break } // unterminated → literal

        flush()
        if let token = parseTag(String(String.UnicodeScalarView(s[(i + 1)..<j]))) { tokens.append(token) }
        i = j + 1
    }
    flush()
    return tokens
}

private func parseTag(_ inner: String) -> Token? {
    var s = inner.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !s.isEmpty, !s.hasPrefix("!"), !s.hasPrefix("?") else { return nil }

    var isClose = false
    if s.hasPrefix("/") { isClose = true; s.removeFirst() }
    if s.hasSuffix("/") { s.removeLast() } // self-closing
    s = s.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !s.isEmpty else { return nil }

    guard let split = s.firstIndex(where: { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" }) else {
        let name = s.lowercased()
        return isClose ? .close(name) : .open(name, [:])
    }
    let name = String(s[s.startIndex..<split]).lowercased()
    if isClose { return .close(name) }
    return .open(name, parseAttributes(String(s[split...])))
}

private func parseAttributes(_ s: String) -> [String: String] {
    var attrs: [String: String] = [:]
    let chars = Array(s)
    let n = chars.count
    var i = 0
    func isWS(_ c: Character) -> Bool { c == " " || c == "\t" || c == "\n" || c == "\r" }

    while i < n {
        while i < n, isWS(chars[i]) { i += 1 }
        if i >= n { break }
        var name = ""
        while i < n, chars[i] != "=", !isWS(chars[i]) { name.append(chars[i]); i += 1 }
        while i < n, isWS(chars[i]) { i += 1 }
        var value = ""
        if i < n, chars[i] == "=" {
            i += 1
            while i < n, isWS(chars[i]) { i += 1 }
            if i < n, chars[i] == "\"" || chars[i] == "'" {
                let q = chars[i]; i += 1
                while i < n, chars[i] != q { value.append(chars[i]); i += 1 }
                if i < n { i += 1 }
            } else {
                while i < n, !isWS(chars[i]) { value.append(chars[i]); i += 1 }
            }
        }
        if !name.isEmpty { attrs[name.lowercased()] = value }
    }
    return attrs
}

// MARK: - Renderer

private struct InlineStyle {
    var bold = false
    var italic = false
    var strike = false
    var code = false
    var pre = false
    var hidden = false
    var link: URL?
}

private struct Renderer {
    private var result = AttributedString()
    private var style = InlineStyle()
    private var frames: [Frame] = []
    private var lists: [ListContext] = []
    private var pendingBreak = 0
    private var needsLeadingTrim = true
    private var emittedCount = 0

    /// A frame is pushed for every opened non-void tag so a close can tell whether it
    /// matches a real open (orphan closes are ignored) and restore the prior style.
    private struct Frame {
        let tag: String
        let saved: InlineStyle
        let appendOnClose: String?
        /// For `ellipsis`: the `emittedCount` at open; the "…" is only appended if the
        /// span actually emitted visible text.
        let emitGuard: Int?
    }
    private struct ListContext { let ordered: Bool; var index: Int }

    mutating func render(_ tokens: [Token]) -> AttributedString {
        for token in tokens {
            switch token {
            case .text(let raw): emitText(raw)
            case .open(let tag, let attrs): open(tag, attrs)
            case .close(let tag): close(tag)
            }
        }
        return trimmed(result)
    }

    // MARK: Emit

    private mutating func emitText(_ raw: String) {
        var text = decodeEntities(raw)
        if !style.pre { text = collapseWhitespace(text) }
        guard !style.hidden else { return }
        if needsLeadingTrim, !style.pre { text = String(text.drop(while: { $0 == " " })) }
        guard !text.isEmpty else { return }
        flushBreak()
        result.append(AttributedString(text, attributes: container(for: style)))
        emittedCount += 1
        needsLeadingTrim = false
    }

    /// Literal text with an explicit style (list markers, img alt). Flushes pending breaks.
    private mutating func emitLiteral(_ text: String, style s: InlineStyle) {
        guard !text.isEmpty, !s.hidden else { return }
        flushBreak()
        result.append(AttributedString(text, attributes: container(for: s)))
        emittedCount += 1
        needsLeadingTrim = false
    }

    /// Appends without flushing a pending break — used for a trailing ellipsis so it
    /// attaches to the text it truncates rather than starting a new line.
    private mutating func appendInline(_ text: String, style s: InlineStyle) {
        guard !text.isEmpty, !s.hidden else { return }
        result.append(AttributedString(text, attributes: container(for: s)))
        emittedCount += 1
        needsLeadingTrim = false
    }

    private mutating func flushBreak() {
        if pendingBreak > 0, !result.characters.isEmpty {
            result.append(AttributedString(String(repeating: "\n", count: pendingBreak)))
        }
        pendingBreak = 0
    }

    private mutating func setBreak(_ n: Int) {
        pendingBreak = max(pendingBreak, n)
        needsLeadingTrim = true
    }

    // MARK: Open / close

    private mutating func pushStyle(_ tag: String, _ modify: (inout InlineStyle) -> Void) {
        frames.append(Frame(tag: tag, saved: style, appendOnClose: nil, emitGuard: nil))
        modify(&style)
    }

    private mutating func pushFrame(_ tag: String, appendOnClose: String?, emitGuard: Int?) {
        frames.append(Frame(tag: tag, saved: style, appendOnClose: appendOnClose, emitGuard: emitGuard))
    }

    private mutating func open(_ tag: String, _ attrs: [String: String]) {
        switch tag {
        case "br": setBreak(1)
        case "hr": setBreak(2)
        case "img": if let alt = attrs["alt"] { emitLiteral(decodeEntities(alt), style: style) }
        case "p": pushFrame(tag, appendOnClose: nil, emitGuard: nil); setBreak(2)
        case "div", "tr": pushFrame(tag, appendOnClose: nil, emitGuard: nil); setBreak(1)
        case "h1", "h2", "h3", "h4", "h5", "h6": pushStyle(tag) { $0.bold = true }; setBreak(2)
        case "blockquote": pushStyle(tag) { $0.italic = true }; setBreak(2)
        case "pre": pushStyle(tag) { $0.code = true; $0.pre = true }; setBreak(2)
        case "ul", "ol":
            pushFrame(tag, appendOnClose: nil, emitGuard: nil)
            lists.append(ListContext(ordered: tag == "ol", index: 0))
            setBreak(1)
        case "li":
            pushFrame(tag, appendOnClose: nil, emitGuard: nil)
            setBreak(1)
            var marker = "• "
            if !lists.isEmpty, lists[lists.count - 1].ordered {
                lists[lists.count - 1].index += 1
                marker = "\(lists[lists.count - 1].index). "
            }
            var plain = style
            plain.bold = false; plain.italic = false; plain.strike = false; plain.code = false; plain.link = nil
            emitLiteral(marker, style: plain)
        case "strong", "b": pushStyle(tag) { $0.bold = true }
        case "em", "i": pushStyle(tag) { $0.italic = true }
        case "del", "s": pushStyle(tag) { $0.strike = true }
        case "code": pushStyle(tag) { $0.code = true }
        case "a": pushStyle(tag) { $0.link = validatedURL(attrs["href"]) }
        case "span":
            let classes = classTokens(attrs["class"])
            if classes.contains("invisible") { pushStyle(tag) { $0.hidden = true } }
            else if classes.contains("ellipsis") { pushFrame(tag, appendOnClose: "…", emitGuard: emittedCount) }
            else { pushFrame(tag, appendOnClose: nil, emitGuard: nil) }
        default:
            break // table/thead/tbody/th/td and unknowns: render inner text inline
        }
    }

    private mutating func close(_ tag: String) {
        // Orphan close (no matching open) → ignore entirely; injecting a break here would
        // add phantom newlines to stray fragments like "text</p>more".
        guard let idx = frames.lastIndex(where: { $0.tag == tag }) else { return }

        while frames.count > idx {
            let frame = frames.removeLast()
            style = frame.saved
            if let append = frame.appendOnClose, frame.emitGuard == nil || emittedCount > frame.emitGuard! {
                appendInline(append, style: style)
            }
        }

        switch tag {
        case "p", "blockquote", "pre", "h1", "h2", "h3", "h4", "h5", "h6": setBreak(2)
        case "div", "li", "tr": setBreak(1)
        case "ul", "ol":
            if !lists.isEmpty { lists.removeLast() }
            setBreak(1)
        default:
            break
        }
    }

    // MARK: Helpers

    private func container(for style: InlineStyle) -> AttributeContainer {
        var container = AttributeContainer()
        var intent: InlinePresentationIntent = []
        if style.bold { intent.insert(.stronglyEmphasized) }
        if style.italic { intent.insert(.emphasized) }
        if style.strike { intent.insert(.strikethrough) }
        if style.code { intent.insert(.code) }
        if !intent.isEmpty { container.inlinePresentationIntent = intent }
        if let link = style.link { container.link = link }
        return container
    }

    private func trimmed(_ input: AttributedString) -> AttributedString {
        var s = input
        while let first = s.characters.first, first == "\n" || first == " " {
            s.removeSubrange(s.startIndex..<s.index(s.startIndex, offsetByCharacters: 1))
        }
        while let last = s.characters.last, last == "\n" || last == " " {
            s.removeSubrange(s.index(s.endIndex, offsetByCharacters: -1)..<s.endIndex)
        }
        return s
    }
}

// MARK: - Free helpers

private func classTokens(_ cls: String?) -> Set<String> {
    guard let cls else { return [] }
    return Set(cls.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" }).map(String.init))
}

/// Collapses whitespace runs to a single space, maps assorted Unicode spaces (incl.
/// NBSP) to a plain space, and drops control chars and zero-width spaces. Iterates
/// **scalars** so a CR+LF pair (one grapheme) is still recognized as whitespace.
private func collapseWhitespace(_ s: String) -> String {
    var out = String.UnicodeScalarView()
    var lastWasSpace = false
    for u in s.unicodeScalars {
        if isCollapsibleSpace(u) {
            if !lastWasSpace { out.append(" "); lastWasSpace = true }
        } else if isDroppable(u) {
            continue
        } else {
            out.append(u)
            lastWasSpace = false
        }
    }
    return String(out)
}

private func isCollapsibleSpace(_ u: Unicode.Scalar) -> Bool {
    switch u.value {
    case 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0x85, 0xA0, 0x1680,
         0x2000...0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000:
        return true
    default:
        return false
    }
}

private func isDroppable(_ u: Unicode.Scalar) -> Bool {
    switch u.value {
    // C0 controls (minus the whitespace ones above), DEL, C1 controls (minus NEL 0x85),
    // zero-width space, and the BOM/zero-width no-break space. ZWJ/ZWNJ are kept (emoji).
    case 0x00...0x08, 0x0E...0x1F, 0x7F...0x84, 0x86...0x9F, 0x200B, 0xFEFF:
        return true
    default:
        return false
    }
}

private func validatedURL(_ href: String?) -> URL? {
    guard let href else { return nil }
    let trimmed = decodeEntities(href).trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = URL(string: trimmed),
          let scheme = url.scheme?.lowercased(),
          scheme == "http" || scheme == "https" || scheme == "mailto"
    else { return nil }
    return url
}

private func decodeEntities(_ s: String) -> String {
    guard s.contains("&") else { return s }
    var out = ""
    var i = s.startIndex
    while i < s.endIndex {
        let c = s[i]
        if c == "&",
           let semi = s[i...].firstIndex(of: ";"),
           s.distance(from: i, to: semi) <= 12,
           let decoded = decodeEntity(String(s[s.index(after: i)..<semi])) {
            out.append(decoded)
            i = s.index(after: semi)
        } else {
            out.append(c)
            i = s.index(after: i)
        }
    }
    return out
}

private func decodeEntity(_ e: String) -> Character? {
    switch e {
    case "amp": return "&"
    case "lt": return "<"
    case "gt": return ">"
    case "quot": return "\""
    case "apos": return "'"
    case "nbsp": return " "
    default:
        if e.hasPrefix("#x") || e.hasPrefix("#X") {
            let digits = e.dropFirst(2)
            guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isHexDigit }),
                  let code = UInt32(digits, radix: 16), let scalar = Unicode.Scalar(code) else { return nil }
            return Character(scalar)
        } else if e.hasPrefix("#") {
            let digits = e.dropFirst(1)
            guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let code = UInt32(digits), let scalar = Unicode.Scalar(code) else { return nil }
            return Character(scalar)
        }
        return nil
    }
}
