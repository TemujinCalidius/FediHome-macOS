import XCTest
@testable import FediHomeKit

final class ComposeV2Tests: XCTestCase {
    /// Round-trips the body through JSON so we can assert its wire shape.
    private func roundTrip(_ body: [String: Any]) throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: body)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: ComposeBody

    func testMinimalNoteBody() throws {
        let body = try roundTrip(ComposeBody.build(content: "  hello  "))
        XCTAssertEqual(body["content"] as? String, "hello")
        XCTAssertNil(body["title"])
        XCTAssertNil(body["description"])
        XCTAssertNil(body["photos"])
        XCTAssertNil(body["scheduledFor"])
        XCTAssertNil(body["crosspostBluesky"])
        XCTAssertNil(body["addToPhotography"])
    }

    func testArticleWithDescription() throws {
        let body = try roundTrip(ComposeBody.build(content: "long body", title: "My Article",
                                                   description: "A short excerpt"))
        XCTAssertEqual(body["title"] as? String, "My Article")
        XCTAssertEqual(body["description"] as? String, "A short excerpt")
    }

    func testWhitespaceTitleAndDescriptionOmitted() throws {
        let body = try roundTrip(ComposeBody.build(content: "x", title: "   ", description: " "))
        XCTAssertNil(body["title"])
        XCTAssertNil(body["description"])
    }

    func testScheduledForISO8601() throws {
        let date = Date(timeIntervalSince1970: 1_790_000_000) // fixed instant
        let body = try roundTrip(ComposeBody.build(content: "later", scheduledFor: date))
        let iso = try XCTUnwrap(body["scheduledFor"] as? String)
        XCTAssertTrue(iso.hasSuffix("Z"), "scheduledFor should be UTC ISO-8601, got \(iso)")
        XCTAssertEqual(ISO8601DateFormatter().date(from: iso), date)
    }

    func testCrosspostFlagsOnlyWhenTrue() throws {
        let on = try roundTrip(ComposeBody.build(content: "x", crosspostBluesky: true, crosspostThreads: true))
        XCTAssertEqual(on["crosspostBluesky"] as? Bool, true)
        XCTAssertEqual(on["crosspostThreads"] as? Bool, true)
        let off = try roundTrip(ComposeBody.build(content: "x"))
        XCTAssertNil(off["crosspostBluesky"])
        XCTAssertNil(off["crosspostThreads"])
    }

    func testPhotosCarryAltAndGalleryFlags() throws {
        let body = try roundTrip(ComposeBody.build(
            content: "pics",
            photos: [ComposePhoto(url: "https://x/a.webp", alt: "A sunset")],
            addToPhotography: true, photoCategory: "landscape"
        ))
        let photos = try XCTUnwrap(body["photos"] as? [[String: Any]])
        XCTAssertEqual(photos.first?["url"] as? String, "https://x/a.webp")
        XCTAssertEqual(photos.first?["alt"] as? String, "A sunset")
        XCTAssertEqual(body["addToPhotography"] as? Bool, true)
        XCTAssertEqual(body["photoCategory"] as? String, "landscape")
    }

    func testVideoAndAudioArrays() throws {
        let body = try roundTrip(ComposeBody.build(
            content: "media",
            videos: [ComposeVideo(url: "https://makertube.net/w/abc", title: "Clip",
                                  embedHost: "makertube.net", embedId: "abc",
                                  iframeSrc: "https://makertube.net/videos/embed/abc")],
            audios: [ComposeAudio(url: "https://x/a.mp3", title: "Song", durationSec: 180, fileSize: 1000)],
            addToVideos: true, addToAudio: true
        ))
        let videos = try XCTUnwrap(body["videos"] as? [[String: Any]])
        XCTAssertEqual(videos.first?["embedId"] as? String, "abc")
        XCTAssertEqual(videos.first?["iframeSrc"] as? String, "https://makertube.net/videos/embed/abc")
        XCTAssertNil(videos.first?["thumbnailUrl"]) // nil omitted
        let audios = try XCTUnwrap(body["audios"] as? [[String: Any]])
        XCTAssertEqual(audios.first?["durationSec"] as? Int, 180)
        XCTAssertEqual(body["addToVideos"] as? Bool, true)
        XCTAssertEqual(body["addToAudio"] as? Bool, true)
        // no categories sent when not provided
        XCTAssertNil(body["videoCategory"])
        XCTAssertNil(body["audioCategory"])
    }

    // MARK: ComposeResult decoding

    func testPublishedResultDecodes() throws {
        let json = Data(#"{"success":true,"post":{"id":"ckx1","slug":"hello","url":"https://fedihome.social/post/hello"}}"#.utf8)
        let result = try JSONDecoder.fediHome.decode(ComposeResult.self, from: json)
        XCTAssertTrue(result.success)
        XCTAssertFalse(result.isScheduled)
        XCTAssertEqual(result.post.webURL?.absoluteString, "https://fedihome.social/post/hello")
    }

    func testScheduledResultDecodes() throws {
        let json = Data("""
        {"success":true,"scheduled":true,"post":{"id":"ckx2","slug":"later",
         "url":"https://fedihome.social/post/later","scheduledFor":"2026-07-15T14:30:00.000Z"}}
        """.utf8)
        let result = try JSONDecoder.fediHome.decode(ComposeResult.self, from: json)
        XCTAssertTrue(result.isScheduled)
        XCTAssertEqual(result.post.scheduledFor, FediDate.parse("2026-07-15T14:30:00.000Z"))
    }

    // MARK: Micropub summary (drafts keep the Micropub path)

    func testHEntryCarriesSummary() throws {
        let body = Micropub.hEntry(content: "body", title: "T", summary: "An excerpt",
                                   photoURLs: [], draft: true)
        let data = try JSONSerialization.data(withJSONObject: body)
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let props = try XCTUnwrap(parsed["properties"] as? [String: Any])
        XCTAssertEqual(props["summary"] as? [String], ["An excerpt"])
        XCTAssertEqual(props["post-status"] as? [String], ["draft"])
    }
}
