import XCTest
@testable import FediHomeKit

final class OwnPostsTests: XCTestCase {
    func testPageDecodesAllStatuses() throws {
        let json = Data("""
        { "posts": [
            { "id": "ckx-article-1",
              "slug": "my-article", "url": "/post/my-article", "title": "My Article",
              "excerpt": "A summary", "category": "article", "type": "article",
              "status": "published", "published": true,
              "publishedAt": "2026-07-01T10:00:00.000Z", "updatedAt": "2026-07-01T10:05:00.000Z",
              "scheduledFor": null, "counts": { "likes": 3, "boosts": 1 },
              "media": { "photos": 2, "videos": 0, "audio": 0 } },
            { "slug": "later", "url": "/post/later", "title": null, "excerpt": null,
              "category": "note", "type": "note", "status": "scheduled", "published": false,
              "publishedAt": "2026-07-15T14:30:00.000Z", "updatedAt": "2026-07-02T09:00:00.000Z",
              "scheduledFor": "2026-07-15T14:30:00.000Z", "counts": { "likes": 0, "boosts": 0 },
              "media": { "photos": 0, "videos": 0, "audio": 0 } },
            { "slug": "wip", "url": "/post/wip", "title": "Draft idea", "excerpt": null,
              "category": "article", "type": "photo", "status": "draft", "published": false,
              "publishedAt": "2026-06-30T08:00:00.000Z", "updatedAt": "2026-06-30T08:00:00.000Z",
              "scheduledFor": null, "counts": { "likes": 0, "boosts": 0 },
              "media": { "photos": 1, "videos": 0, "audio": 0 } }
          ],
          "nextCursor": "2026-06-30T08:00:00.000Z" }
        """.utf8)
        let page = try JSONDecoder.fediHome.decode(OwnPostsPage.self, from: json)
        XCTAssertEqual(page.posts.count, 3)
        XCTAssertEqual(page.nextCursor, "2026-06-30T08:00:00.000Z")

        let article = page.posts[0]
        XCTAssertEqual(article.status, .published)
        XCTAssertEqual(article.displayTitle, "My Article")
        XCTAssertEqual(article.counts.likes, 3)
        XCTAssertEqual(article.media.photos, 2)
        XCTAssertFalse(article.media.isEmpty)
        // Relative URL resolves against the instance.
        let base = URL(string: "https://fedihome.social")!
        XCTAssertEqual(article.webURL(relativeTo: base)?.absoluteString,
                       "https://fedihome.social/post/my-article")

        let scheduled = page.posts[1]
        XCTAssertEqual(scheduled.status, .scheduled)
        XCTAssertNotNil(scheduled.scheduledFor)
        XCTAssertEqual(scheduled.displayTitle, "Untitled note")

        XCTAssertEqual(page.posts[2].status, .draft)
        XCTAssertEqual(page.posts[2].type, "photo")

        // id → serverId (edit gate); rows without it (older servers) still decode.
        XCTAssertEqual(article.serverId, "ckx-article-1")
        XCTAssertNil(page.posts[1].serverId)
        XCTAssertEqual(article.id, "my-article") // Identifiable stays slug-based
    }

    func testDisplayTitleFallsBackToPreview() throws {
        func post(title: String?, excerpt: String?, preview: String?) throws -> OwnPost {
            func field(_ v: String?) -> String { v.map { "\"\($0)\"" } ?? "null" }
            let json = Data("""
            { "slug": "s", "url": "/post/s",
              "title": \(field(title)), "excerpt": \(field(excerpt)), "preview": \(field(preview)),
              "category": "note", "type": "note", "status": "published", "published": true,
              "publishedAt": "2026-07-01T10:00:00.000Z", "updatedAt": "2026-07-01T10:00:00.000Z",
              "scheduledFor": null, "counts": { "likes": 0, "boosts": 0 },
              "media": { "photos": 0, "videos": 0, "audio": 0 } }
            """.utf8)
            return try JSONDecoder.fediHome.decode(OwnPost.self, from: json)
        }
        // Title-less note with a preview → the body preview becomes the display title.
        XCTAssertEqual(try post(title: nil, excerpt: nil, preview: "First line of the note").displayTitle,
                       "First line of the note")
        // A genuinely empty preview ("") → the placeholder.
        XCTAssertEqual(try post(title: nil, excerpt: nil, preview: "").displayTitle, "Untitled note")
        // Precedence: title beats preview; excerpt beats preview.
        XCTAssertEqual(try post(title: "T", excerpt: nil, preview: "P").displayTitle, "T")
        XCTAssertEqual(try post(title: nil, excerpt: "E", preview: "P").displayTitle, "E")

        // A pre-v1.15.0 server omits `preview` entirely — still decodes (nil), placeholder shown.
        let legacy = try JSONDecoder.fediHome.decode(OwnPost.self, from: Data("""
        { "slug": "s", "url": "/post/s", "title": null, "excerpt": null,
          "category": "note", "type": "note", "status": "published", "published": true,
          "publishedAt": "2026-07-01T10:00:00.000Z", "updatedAt": "2026-07-01T10:00:00.000Z",
          "scheduledFor": null, "counts": { "likes": 0, "boosts": 0 },
          "media": { "photos": 0, "videos": 0, "audio": 0 } }
        """.utf8))
        XCTAssertNil(legacy.preview)
        XCTAssertEqual(legacy.displayTitle, "Untitled note")
    }

    func testDecodesContentHtml() throws {
        // Server returns the sanitized HTML body (FediHome#292) for the full-post view.
        let post = try JSONDecoder.fediHome.decode(OwnPost.self, from: Data("""
        { "slug": "s", "url": "/post/s", "title": "T", "excerpt": null, "preview": null,
          "contentHtml": "<p>Hello <strong>world</strong></p>",
          "category": "article", "type": "article", "status": "published", "published": true,
          "publishedAt": "2026-07-01T10:00:00.000Z", "updatedAt": "2026-07-01T10:00:00.000Z",
          "scheduledFor": null, "counts": { "likes": 0, "boosts": 0 },
          "media": { "photos": 0, "videos": 0, "audio": 0 } }
        """.utf8))
        XCTAssertEqual(post.contentHtml, "<p>Hello <strong>world</strong></p>")

        // A server without the field (or an older one) still decodes → nil.
        let legacy = try JSONDecoder.fediHome.decode(OwnPost.self, from: Data("""
        { "slug": "s2", "url": "/post/s2", "title": "T", "excerpt": null,
          "category": "article", "type": "article", "status": "published", "published": true,
          "publishedAt": "2026-07-01T10:00:00.000Z", "updatedAt": "2026-07-01T10:00:00.000Z",
          "scheduledFor": null, "counts": { "likes": 0, "boosts": 0 },
          "media": { "photos": 0, "videos": 0, "audio": 0 } }
        """.utf8))
        XCTAssertNil(legacy.contentHtml)
    }

    func testPostSourceDecodes() throws {
        let json = Data("""
        { "type": ["h-entry"], "properties": {
            "name": ["My Article"], "content": ["Full **markdown** body"],
            "summary": ["A short excerpt"], "published": ["2026-07-01T10:00:00.000Z"],
            "category": ["swift"], "post-status": ["published"] } }
        """.utf8)
        let source = try JSONDecoder.fediHome.decode(PostSource.self, from: json)
        XCTAssertEqual(source.title, "My Article")
        XCTAssertEqual(source.content, "Full **markdown** body")
        XCTAssertEqual(source.summary, "A short excerpt")
        XCTAssertFalse(source.isDraft)
    }

    func testComposeBodyCarriesEditingPostId() throws {
        let body = ComposeBody.build(content: "edited text", title: "T", editingPostId: "ckx1")
        let data = try JSONSerialization.data(withJSONObject: body)
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(parsed["editingPostId"] as? String, "ckx1")
        XCTAssertNil(parsed["photos"]) // omitted media → server preserves it
    }
}
