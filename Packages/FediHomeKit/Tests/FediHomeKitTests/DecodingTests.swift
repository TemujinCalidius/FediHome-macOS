import XCTest
@testable import FediHomeKit

final class DecodingTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: "json"),
            "missing fixture \(name).json"
        )
        return try Data(contentsOf: url)
    }

    func testAccountDecodes() throws {
        let account = try JSONDecoder.fediHome.decode(Account.self, from: fixture("account"))
        XCTAssertEqual(account.me, "https://fedihome.social")
        XCTAssertEqual(account.domain, "fedihome.social")
        XCTAssertEqual(account.counts.posts, 128)
        XCTAssertEqual(account.displayName, "Sam's Home")
        XCTAssertEqual(account.avatarURL?.host, "fedihome.social")
    }

    func testFeedDecodesWithBothDateFormats() throws {
        let page = try JSONDecoder.fediHome.decode(FeedPage.self, from: fixture("feed"))
        XCTAssertEqual(page.posts.count, 2)
        XCTAssertEqual(page.nextCursor, "2026-07-01T09:00:00Z")

        let base = URL(string: "https://fedihome.social")!
        let first = page.posts[0]
        XCTAssertEqual(first.fediHandle, "@alice@mastodon.social")
        XCTAssertEqual(first.authorName, "Alice")
        XCTAssertFalse(first.isBoost)
        XCTAssertEqual(first.media(relativeTo: base).count, 1)
        XCTAssertEqual(first.media(relativeTo: base).first?.kind, .image)
        XCTAssertEqual(first.likeCount, 3)
        // Fractional-seconds date parsed.
        XCTAssertEqual(first.publishedAt, FediDate.parse("2026-07-01T10:30:00.735Z"))

        let second = page.posts[1]
        XCTAssertTrue(second.isBoost)
        XCTAssertTrue(second.isReply)
        XCTAssertEqual(second.authorName, "bob") // displayName null → username fallback
        XCTAssertNil(second.likeCount)
        XCTAssertTrue(second.media(relativeTo: base).isEmpty)
        // Plain (no fractional seconds) date parsed via the lenient fallback.
        XCTAssertEqual(second.publishedAt, FediDate.parse("2026-07-01T09:00:00Z"))
    }

    func testNotificationsDecode() throws {
        let notifs = try JSONDecoder.fediHome.decode(NotificationsResponse.self, from: fixture("notifications"))
        XCTAssertEqual(notifs.count, 3)
        XCTAssertEqual(notifs.items.count, 3)
        XCTAssertEqual(notifs.items[0].type, .like)
        XCTAssertEqual(notifs.items[1].type, .follow)
        XCTAssertEqual(notifs.items[2].type, .update)
        XCTAssertEqual(notifs.categoryCounts["follow"], 1)
    }

    func testUnknownNotificationTypeFallsBack() throws {
        let json = Data("""
        { "count": 1, "items": [
          { "id": "x", "type": "poke", "source": "fedi", "actor": "A",
            "actorUrl": null, "avatarUrl": null, "summary": "poked you",
            "targetUrl": null, "maintenanceId": null, "createdAt": "2026-07-01T08:00:00Z" }
        ], "categoryCounts": { "poke": 1 } }
        """.utf8)
        let notifs = try JSONDecoder.fediHome.decode(NotificationsResponse.self, from: json)
        XCTAssertEqual(notifs.items.first?.type, .unknown("poke"))
    }
}
