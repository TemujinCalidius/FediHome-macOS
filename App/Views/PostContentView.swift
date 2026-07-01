import SwiftUI
import FediHomeKit

/// Renders a post's body. Prefers the server's plain-text `content`; when only
/// `contentHtml` is present, falls back to a minimal tag/entity strip.
///
/// TODO (next slice): rich HTML rendering (links, mentions, hashtags) via an
/// `AttributedString` bridge, normalized to the platform font/color.
struct PostContentView: View {
    let post: FediPost

    var body: some View {
        Text(displayText)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var displayText: String {
        if !post.content.isEmpty { return post.content }
        if let html = post.contentHtml { return Self.strip(html) }
        return ""
    }

    static func strip(_ html: String) -> String {
        var text = html
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")
            .replacingOccurrences(of: "</p>", with: "\n\n")
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&nbsp;": " "]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
