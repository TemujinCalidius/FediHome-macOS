import XCTest
@testable import FediHomeKit

final class MediaAndInteractionsTests: XCTestCase {
    private let base = URL(string: "https://fedihome.social")!

    // MARK: MediaURL.resolve

    func testResolveAbsoluteURLUnchanged() {
        let resolved = MediaURL.resolve("https://files.mastodon.social/a.jpg", relativeTo: base)
        XCTAssertEqual(resolved?.absoluteString, "https://files.mastodon.social/a.jpg")
    }

    func testResolveRelativePathAgainstBase() {
        let resolved = MediaURL.resolve("/uploads/fedi/2026/07/abc.jpg", relativeTo: base)
        XCTAssertEqual(resolved?.absoluteString, "https://fedihome.social/uploads/fedi/2026/07/abc.jpg")
    }

    func testResolveEmptyIsNil() {
        XCTAssertNil(MediaURL.resolve("   ", relativeTo: base))
    }

    // MARK: media(relativeTo:) classification

    private func post(mediaUrls: [String], mediaTypes: [String], apId: String = "https://m.social/a/1") -> FediPost {
        FediPost(
            id: "id", actorUri: "https://m.social/users/a", apId: apId,
            content: "", contentHtml: nil, mediaUrls: mediaUrls, mediaTypes: mediaTypes,
            username: "a", domain: "m.social", displayName: nil, avatarUrl: nil,
            publishedAt: Date(timeIntervalSince1970: 0), createdAt: Date(timeIntervalSince1970: 0),
            isOutgoing: false, boostedBy: nil, boostedByName: nil, inReplyTo: nil, conversationId: nil,
            embedUrl: nil, embedTitle: nil, embedDescription: nil, embedImage: nil, embedSiteName: nil,
            likeCount: nil, boostCount: nil, replyCount: nil, countsFetchedAt: nil,
            likedByMe: false, boostedByMe: false
        )
    }

    func testRelativeImageResolvedAndClassified() {
        let media = post(mediaUrls: ["/uploads/fedi/2026/07/x.jpg"], mediaTypes: ["image"]).media(relativeTo: base)
        XCTAssertEqual(media.count, 1)
        XCTAssertEqual(media.first?.kind, .image)
        XCTAssertEqual(media.first?.url.absoluteString, "https://fedihome.social/uploads/fedi/2026/07/x.jpg")
    }

    func testProxiedVideoFileIsInlinePlayable() {
        let media = post(mediaUrls: ["/uploads/fedi/2026/07/clip.mp4"], mediaTypes: ["video"]).media(relativeTo: base)
        XCTAssertEqual(media.first?.kind, .video)
    }

    func testRemoteDirectVideoFileIsInlinePlayable() {
        let media = post(mediaUrls: ["https://cdn.example.com/v/clip.webm"], mediaTypes: ["video"]).media(relativeTo: base)
        XCTAssertEqual(media.first?.kind, .video)
    }

    func testStreamingPageVideoBecomesLink() {
        let media = post(mediaUrls: ["https://www.youtube.com/watch?v=abc123"], mediaTypes: ["video"]).media(relativeTo: base)
        XCTAssertEqual(media.first?.kind, .link)
    }

    func testParallelArraysZipEvenWhenTypesShort() {
        let media = post(mediaUrls: ["/a.jpg", "/b.jpg"], mediaTypes: ["image"]).media(relativeTo: base)
        XCTAssertEqual(media.count, 2) // missing type padded to "image"
        XCTAssertEqual(media.map(\.kind), [.image, .image])
    }

    // MARK: embedCard gating

    func testEmbedCardShownWithTitleAndResolvesImage() throws {
        var p = post(mediaUrls: [], mediaTypes: [])
        p = FediPost(from: p, embedUrl: "https://example.com/article", embedTitle: "Title",
                     embedDescription: "Desc", embedImage: "/uploads/fedi/e.jpg", embedSiteName: "Example")
        let card = try XCTUnwrap(p.embedCard(relativeTo: base))
        XCTAssertEqual(card.url.absoluteString, "https://example.com/article")
        XCTAssertEqual(card.imageURL?.absoluteString, "https://fedihome.social/uploads/fedi/e.jpg")
        XCTAssertEqual(card.displaySite, "Example")
    }

    func testEmbedCardHiddenWithoutTitleOrDescription() {
        var p = post(mediaUrls: [], mediaTypes: [])
        p = FediPost(from: p, embedUrl: "https://example.com", embedTitle: nil,
                     embedDescription: nil, embedImage: "/uploads/fedi/e.jpg", embedSiteName: "Example")
        XCTAssertNil(p.embedCard(relativeTo: base)) // no title/description → no card
    }

    func testShareURLIsApIdWhenWebURL() {
        XCTAssertEqual(post(mediaUrls: [], mediaTypes: []).shareURL?.absoluteString, "https://m.social/a/1")
    }

    // MARK: Synthetic boost apId resolution (write actions must target the original)

    func testInteractionApIdStripsSyntheticBoostPrefix() {
        // The actorUri segment itself contains "://", so the resolver must take the LAST
        // http(s) segment (matching the server's greedy `^boost:.*:(https?://.*)$`).
        let synthetic = "boost:https://booster.example/users/x:https://origin.example/notes/123"
        let p = post(mediaUrls: [], mediaTypes: [], apId: synthetic)
        XCTAssertEqual(p.interactionApId, "https://origin.example/notes/123")
        XCTAssertEqual(p.shareURL?.absoluteString, "https://origin.example/notes/123")
    }

    func testInteractionApIdUnchangedForNormalPost() {
        let p = post(mediaUrls: [], mediaTypes: [], apId: "https://m.social/a/1")
        XCTAssertEqual(p.interactionApId, "https://m.social/a/1")
    }

    // MARK: New response models

    func testPostCountsDecode() throws {
        let json = Data(#"{"likeCount":12,"boostCount":3,"replyCount":null,"countsFetchedAt":"2026-07-01T12:00:00.500Z"}"#.utf8)
        let counts = try JSONDecoder.fediHome.decode(PostCounts.self, from: json)
        XCTAssertEqual(counts.likeCount, 12)
        XCTAssertEqual(counts.boostCount, 3)
        XCTAssertNil(counts.replyCount)
        XCTAssertNotNil(counts.countsFetchedAt)
    }

    func testConversationThreadDecode() throws {
        let json = Data("""
        { "thread": [
          { "id": "p1", "actorUri": "https://m.social/users/a", "apId": "https://m.social/a/1",
            "content": "root", "contentHtml": "<p>root</p>", "mediaUrls": [], "mediaTypes": [],
            "username": "a", "domain": "m.social", "displayName": "A", "avatarUrl": null,
            "publishedAt": "2026-07-01T10:00:00Z", "createdAt": "2026-07-01T10:00:00Z", "isOutgoing": false,
            "boostedBy": null, "boostedByName": null, "inReplyTo": null, "conversationId": "c1",
            "embedUrl": null, "embedTitle": null, "embedDescription": null, "embedImage": null, "embedSiteName": null,
            "likeCount": null, "boostCount": null, "replyCount": null, "countsFetchedAt": null,
            "likedByMe": false, "boostedByMe": false }
        ] }
        """.utf8)
        let convo = try JSONDecoder.fediHome.decode(ConversationThread.self, from: json)
        XCTAssertEqual(convo.thread.count, 1)
        XCTAssertEqual(convo.thread.first?.content, "root")
    }
}

/// Test-only copy helper to vary embed fields without repeating the 26-field initializer.
private extension FediPost {
    init(from p: FediPost, embedUrl: String?, embedTitle: String?, embedDescription: String?,
         embedImage: String?, embedSiteName: String?) {
        self.init(
            id: p.id, actorUri: p.actorUri, apId: p.apId, content: p.content, contentHtml: p.contentHtml,
            mediaUrls: p.mediaUrls, mediaTypes: p.mediaTypes, username: p.username, domain: p.domain,
            displayName: p.displayName, avatarUrl: p.avatarUrl, publishedAt: p.publishedAt, createdAt: p.createdAt,
            isOutgoing: p.isOutgoing, boostedBy: p.boostedBy, boostedByName: p.boostedByName,
            inReplyTo: p.inReplyTo, conversationId: p.conversationId,
            embedUrl: embedUrl, embedTitle: embedTitle, embedDescription: embedDescription,
            embedImage: embedImage, embedSiteName: embedSiteName,
            likeCount: p.likeCount, boostCount: p.boostCount, replyCount: p.replyCount,
            countsFetchedAt: p.countsFetchedAt, likedByMe: p.likedByMe, boostedByMe: p.boostedByMe
        )
    }
}
