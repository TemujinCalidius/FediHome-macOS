import SwiftUI
import FediHomeKit

/// Renders a post's body as rich text: the server's sanitized `contentHtml` is
/// converted to an `AttributedString` by `FediHTML` (links/mentions/hashtags become
/// tappable accent-colored runs; bold/italic/strike/code render natively), falling
/// back to the plain-text `content` when there's no HTML. Parsing happens off the
/// main thread and is cached per post id.
struct PostContentView: View {
    let post: FediPost

    @State private var rendered: AttributedString?

    var body: some View {
        Text(rendered ?? AttributedString(post.content))
            .tint(.accentColor)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .task(id: post.id) {
                let html = post.contentHtml
                let fallback = post.content
                rendered = await Task.detached(priority: .userInitiated) {
                    Self.render(html: html, fallback: fallback)
                }.value
            }
    }

    private static func render(html: String?, fallback: String) -> AttributedString {
        if let html, !html.isEmpty {
            let attributed = FediHTML.attributedString(from: html)
            if !attributed.characters.isEmpty { return attributed }
        }
        return AttributedString(fallback)
    }
}
