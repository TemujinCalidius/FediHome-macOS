import SwiftUI
import FediHomeKit

/// Renders a post's body as rich text: sanitized `html` is converted to an `AttributedString`
/// by `FediHTML` (links/mentions/hashtags become tappable accent-colored runs; bold/italic/
/// strike/code render natively), falling back to plain `fallback` text when there's no HTML.
/// Parsing happens off the main thread and is cached per `cacheID`. Used by the feed/thread
/// (from a `FediPost`) and by "My Posts" (from an `OwnPost`).
struct PostContentView: View {
    let html: String?
    let fallback: String
    let cacheID: String

    @State private var rendered: AttributedString?

    var body: some View {
        Text(rendered ?? AttributedString(fallback))
            .tint(.accentColor)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .task(id: cacheID) {
                let bodyHTML = html
                let bodyFallback = fallback
                rendered = await Task.detached(priority: .userInitiated) {
                    Self.render(html: bodyHTML, fallback: bodyFallback)
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
