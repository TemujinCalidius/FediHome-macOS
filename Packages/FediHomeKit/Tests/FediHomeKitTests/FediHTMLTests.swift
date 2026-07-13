import XCTest
@testable import FediHomeKit

final class FediHTMLTests: XCTestCase {
    // MARK: Helpers

    private func text(_ html: String) -> String {
        FediHTML.plainText(from: html)
    }

    private func links(_ html: String) -> [(text: String, url: String)] {
        let a = FediHTML.attributedString(from: html)
        return a.runs.compactMap { run in
            guard let link = run.link else { return nil }
            return (String(a[run.range].characters), link.absoluteString)
        }
    }

    private func hasIntent(_ html: String, _ intent: InlinePresentationIntent, containing needle: String) -> Bool {
        let a = FediHTML.attributedString(from: html)
        for run in a.runs {
            if let ip = run.inlinePresentationIntent, ip.contains(intent),
               String(a[run.range].characters).contains(needle) {
                return true
            }
        }
        return false
    }

    // MARK: Text structure

    func testPlainParagraph() {
        XCTAssertEqual(text("<p>hi</p>"), "hi")
    }

    func testMultipleParagraphsSeparatedByBlankLine() {
        XCTAssertEqual(text("<p>one</p><p>two</p>"), "one\n\ntwo")
    }

    func testBreaksBecomeNewlines() {
        XCTAssertEqual(text("<p>Line one<br>Line two<br>Line three</p>"), "Line one\nLine two\nLine three")
    }

    func testEntitiesDecode() {
        XCTAssertEqual(text("<p>a &amp; b &lt;c&gt; &quot;d&quot; &#39;e&#39; &#x263A;</p>"), "a & b <c> \"d\" 'e' ☺")
    }

    func testWhitespaceCollapsed() {
        XCTAssertEqual(text("<p>too    many     spaces\n\tand tabs</p>"), "too many spaces and tabs")
    }

    // MARK: Links / mentions / hashtags

    func testMentionLink() {
        let result = links("<p><a href=\"https://example.com/user\" class=\"mention\" rel=\"ugc\">@user@example.com</a> nice post!</p>")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.text, "@user@example.com")
        XCTAssertEqual(result.first?.url, "https://example.com/user")
        XCTAssertEqual(text("<p><a href=\"https://example.com/user\" class=\"mention\" rel=\"ugc\">@user@example.com</a> nice post!</p>"),
                       "@user@example.com nice post!")
    }

    func testHashtagLink() {
        let result = links("<p>Test <a href=\"https://mastodon.social/tags/fediverse\" class=\"hashtag\" rel=\"tag\">#fediverse</a> tag</p>")
        XCTAssertEqual(result.first?.text, "#fediverse")
        XCTAssertEqual(result.first?.url, "https://mastodon.social/tags/fediverse")
    }

    func testExternalLink() {
        let result = links("<p>Check out <a href=\"https://example.com\" rel=\"nofollow noopener noreferrer\" target=\"_blank\">https://example.com</a></p>")
        XCTAssertEqual(result.first?.text, "https://example.com")
        XCTAssertEqual(result.first?.url, "https://example.com")
    }

    /// Mastodon's URL-truncation idiom: hide `invisible`, keep `ellipsis` + "…".
    func testInvisibleEllipsisTruncation() {
        let html = "<p>Check this <a href=\"https://example.com/very/long/url/that/needs/truncation\"><span class=\"invisible\">https://</span><span class=\"ellipsis\">example.com/very/long/url</span><span class=\"invisible\">/that/needs/truncation</span></a> out</p>"
        XCTAssertEqual(text(html), "Check this example.com/very/long/url… out")
        let result = links(html)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.text, "example.com/very/long/url…")
        XCTAssertEqual(result.first?.url, "https://example.com/very/long/url/that/needs/truncation")
    }

    func testDangerousSchemeIsNotLinked() {
        // Sanitizer strips these upstream, but be defensive: no javascript: link runs.
        XCTAssertTrue(links("<p><a href=\"javascript:alert(1)\">click</a></p>").isEmpty)
        XCTAssertEqual(text("<p><a href=\"javascript:alert(1)\">click</a></p>"), "click")
    }

    // MARK: Inline formatting

    func testBoldItalicStrikeCode() {
        XCTAssertTrue(hasIntent("<p><strong>bold</strong></p>", .stronglyEmphasized, containing: "bold"))
        XCTAssertTrue(hasIntent("<p><b>bold</b></p>", .stronglyEmphasized, containing: "bold"))
        XCTAssertTrue(hasIntent("<p><em>it</em></p>", .emphasized, containing: "it"))
        XCTAssertTrue(hasIntent("<p><i>it</i></p>", .emphasized, containing: "it"))
        XCTAssertTrue(hasIntent("<p><del>gone</del></p>", .strikethrough, containing: "gone"))
        XCTAssertTrue(hasIntent("<p><code>x = 1</code></p>", .code, containing: "x = 1"))
    }

    func testHeadingsAreBoldAndBlocked() {
        let html = "<h2>Write Posts</h2><p>body</p>"
        XCTAssertEqual(text(html), "Write Posts\n\nbody")
        XCTAssertTrue(hasIntent(html, .stronglyEmphasized, containing: "Write Posts"))
    }

    func testNestedBoldItalic() {
        XCTAssertTrue(hasIntent("<p><strong>a <em>b</em></strong></p>", .emphasized, containing: "b"))
        XCTAssertTrue(hasIntent("<p><strong>a <em>b</em></strong></p>", .stronglyEmphasized, containing: "b"))
    }

    // MARK: Lists, images, blockquote

    func testUnorderedList() {
        XCTAssertEqual(text("<ul><li>one</li><li>two</li></ul>"), "• one\n• two")
    }

    func testOrderedList() {
        XCTAssertEqual(text("<ol><li>first</li><li>second</li></ol>"), "1. first\n2. second")
    }

    func testImageRendersAltText() {
        XCTAssertEqual(text("<p>hey <img class=\"emoji\" alt=\":wave:\" src=\"https://x/e.png\"> there</p>"), "hey :wave: there")
    }

    func testBlockquote() {
        XCTAssertEqual(text("<blockquote>quoted</blockquote><p>after</p>"), "quoted\n\nafter")
    }

    // MARK: Robustness (should never crash, always produce sane text)

    func testMalformedInputsDoNotCrash() {
        _ = text("<p>unclosed <strong>bold")
        _ = text("a < b and c > d")
        _ = text("<<>><p></p>")
        _ = text("<a href=>broken</a>")
        _ = text("<!-- comment --><p>ok</p>")
        _ = text("")
        _ = text("no tags at all")
        XCTAssertEqual(text("<p>unclosed <strong>bold"), "unclosed bold")
        XCTAssertEqual(text("<!-- hi --><p>ok</p>"), "ok")
        XCTAssertEqual(text("plain text"), "plain text")
    }

    func testFullContentFromSeedExample() {
        let html = "<p>Welcome to my FediHome! This is my first post.</p><p><em>This is a demo post - feel free to delete it.</em></p>"
        XCTAssertEqual(text(html), "Welcome to my FediHome! This is my first post.\n\nThis is a demo post - feel free to delete it.")
    }
}
