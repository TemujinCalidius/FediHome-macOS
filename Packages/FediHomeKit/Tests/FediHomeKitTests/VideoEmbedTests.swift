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
}
