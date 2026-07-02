import XCTest
@testable import FediHomeKit

final class VideoEmbedTests: XCTestCase {
    private func embed(_ s: String) -> String? {
        URL(string: s).flatMap { VideoEmbed.embedURL(for: $0) }?.absoluteString
    }

    func testYouTubeWatch() {
        XCTAssertEqual(embed("https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
                       "https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1&playsinline=1")
    }

    func testYouTubeWatchWithExtraParams() {
        XCTAssertEqual(embed("https://www.youtube.com/watch?v=abc123&list=PL&t=42"),
                       "https://www.youtube.com/embed/abc123?autoplay=1&playsinline=1")
    }

    func testYouTubeShortLink() {
        XCTAssertEqual(embed("https://youtu.be/abc123?t=5"),
                       "https://www.youtube.com/embed/abc123?autoplay=1&playsinline=1")
    }

    func testYouTubeShorts() {
        XCTAssertEqual(embed("https://www.youtube.com/shorts/xyz789"),
                       "https://www.youtube.com/embed/xyz789?autoplay=1&playsinline=1")
    }

    func testVimeo() {
        XCTAssertEqual(embed("https://vimeo.com/123456789"),
                       "https://player.vimeo.com/video/123456789?autoplay=1")
    }

    func testVimeoNonNumericIsNotEmbeddable() {
        XCTAssertNil(embed("https://vimeo.com/channels/staffpicks"))
    }

    func testPeerTubeShortWatch() {
        XCTAssertEqual(embed("https://makertube.net/w/abcDEF12"),
                       "https://makertube.net/videos/embed/abcDEF12?autoplay=1")
    }

    func testPeerTubeVideosWatch() {
        XCTAssertEqual(embed("https://framatube.org/videos/watch/9c9de5e8-0a1e-484a-b099-e80766180a6d"),
                       "https://framatube.org/videos/embed/9c9de5e8-0a1e-484a-b099-e80766180a6d?autoplay=1")
    }

    func testUnrecognizedIsNil() {
        XCTAssertNil(embed("https://example.com/some/article"))
        XCTAssertNil(embed("https://mastodon.social/@user/123")) // profile/post, not a video
        XCTAssertNil(embed("https://example.com")) // no path
    }

    // MARK: embedInfo (compose-side metadata)

    private func info(_ s: String) -> VideoEmbed.EmbedInfo? {
        URL(string: s).flatMap { VideoEmbed.embedInfo(for: $0) }
    }

    func testEmbedInfoPeerTube() {
        let peertube = info("https://makertube.net/w/abcDEF12")
        XCTAssertEqual(peertube?.embedHost, "makertube.net")
        XCTAssertEqual(peertube?.embedId, "abcDEF12")
        XCTAssertEqual(peertube?.iframeSrc, "https://makertube.net/videos/embed/abcDEF12")

        let watch = info("https://framatube.org/videos/watch/9c9de5e8-0a1e")
        XCTAssertEqual(watch?.iframeSrc, "https://framatube.org/videos/embed/9c9de5e8-0a1e")
    }

    func testEmbedInfoYouTubeAndVimeo() {
        let yt = info("https://www.youtube.com/watch?v=dQw4w9WgXcQ")
        XCTAssertEqual(yt?.embedHost, "www.youtube.com")
        XCTAssertEqual(yt?.embedId, "dQw4w9WgXcQ")
        XCTAssertEqual(yt?.iframeSrc, "https://www.youtube.com/embed/dQw4w9WgXcQ") // no autoplay

        let vimeo = info("https://vimeo.com/123456789")
        XCTAssertEqual(vimeo?.embedHost, "player.vimeo.com")
        XCTAssertEqual(vimeo?.iframeSrc, "https://player.vimeo.com/video/123456789")
    }

    func testEmbedInfoUnrecognizedIsNil() {
        XCTAssertNil(info("https://example.com/blog/post"))
        XCTAssertNil(info("https://vimeo.com/channels/staffpicks"))
    }
}
