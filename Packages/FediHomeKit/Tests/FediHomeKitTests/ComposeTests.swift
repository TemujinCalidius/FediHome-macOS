import XCTest
@testable import FediHomeKit

final class ComposeTests: XCTestCase {
    /// Round-trips the h-entry through JSON so we can assert its shape.
    private func hEntry(content: String, title: String?, photoURLs: [String], draft: Bool) throws -> [String: Any] {
        let body = Micropub.hEntry(content: content, title: title, photoURLs: photoURLs, draft: draft)
        let data = try JSONSerialization.data(withJSONObject: body)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func properties(_ body: [String: Any]) throws -> [String: [String]] {
        // All h-entry property values are arrays of strings in our usage.
        let props = try XCTUnwrap(body["properties"] as? [String: Any])
        return props.mapValues { ($0 as? [Any])?.compactMap { $0 as? String } ?? [] }
    }

    func testNoteHasContentAndNoName() throws {
        let body = try hEntry(content: "hello world", title: nil, photoURLs: [], draft: false)
        XCTAssertEqual(body["type"] as? [String], ["h-entry"])
        let props = try properties(body)
        XCTAssertEqual(props["content"], ["hello world"])
        XCTAssertNil(props["name"])          // no title → note (→ Journal)
        XCTAssertNil(props["photo"])
        XCTAssertNil(props["post-status"])
    }

    func testTitleMakesArticle() throws {
        let props = try properties(try hEntry(content: "body", title: "My Title", photoURLs: [], draft: false))
        XCTAssertEqual(props["name"], ["My Title"]) // name present → article
        XCTAssertEqual(props["content"], ["body"])
    }

    func testPhotosAttached() throws {
        let props = try properties(try hEntry(content: "pics", title: nil,
                                              photoURLs: ["https://x/a.jpg", "https://x/b.jpg"], draft: false))
        XCTAssertEqual(props["photo"], ["https://x/a.jpg", "https://x/b.jpg"])
    }

    func testDraftStatus() throws {
        let props = try properties(try hEntry(content: "wip", title: nil, photoURLs: [], draft: true))
        XCTAssertEqual(props["post-status"], ["draft"])
    }

    func testWhitespaceTrimmedAndEmptyOmitted() throws {
        let props = try properties(try hEntry(content: "  hi  ", title: "   ", photoURLs: [], draft: false))
        XCTAssertEqual(props["content"], ["hi"])
        XCTAssertNil(props["name"]) // whitespace-only title omitted → stays a note
    }

    func testMediaUploadDecodesImageAndAudio() throws {
        let image = try JSONDecoder.fediHome.decode(MediaUpload.self, from: Data(#"{"url":"https://x/a.webp"}"#.utf8))
        XCTAssertEqual(image.uploadedURL?.absoluteString, "https://x/a.webp")
        XCTAssertNil(image.kind)

        let audio = try JSONDecoder.fediHome.decode(MediaUpload.self, from: Data(#"{"url":"https://x/a.mp3","durationSec":180,"fileSize":2880000,"kind":"audio"}"#.utf8))
        XCTAssertEqual(audio.kind, "audio")
        XCTAssertEqual(audio.durationSec, 180)
    }
}
