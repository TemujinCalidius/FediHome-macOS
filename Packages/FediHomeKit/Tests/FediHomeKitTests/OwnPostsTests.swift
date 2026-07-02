import XCTest
@testable import FediHomeKit

final class OwnPostsTests: XCTestCase {
    func testPageDecodesAllStatuses() throws {
        let json = Data("""
        { "posts": [
            { "slug": "my-article", "url": "/post/my-article", "title": "My Article",
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
    }
}
