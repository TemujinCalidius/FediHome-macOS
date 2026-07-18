import XCTest
@testable import FediHomeKit

final class MediaCategoriesTests: XCTestCase {
    func testSlugifyMirrorsServerRules() {
        XCTAssertEqual(CategorySlug.slugify("Photo Walk"), "photo-walk")
        XCTAssertEqual(CategorySlug.slugify("  Street  Photography!! "), "street-photography")
        XCTAssertEqual(CategorySlug.slugify("already-a-slug"), "already-a-slug")
        XCTAssertEqual(CategorySlug.slugify("General"), "general")
        XCTAssertEqual(CategorySlug.slugify("---"), "")   // punctuation-only → dropped
        XCTAssertEqual(CategorySlug.slugify(""), "")
    }

    func testServerConfigDecodesMediaCategories() throws {
        let json = Data(#"""
        {"categories":["note"],
         "mediaCategories":{
           "photos":[{"slug":"general","label":"General"},{"slug":"photo-walk","label":"Photo Walk"}],
           "videos":[{"slug":"general","label":"General"}],
           "audio":[{"slug":"general","label":"General"}]}}
        """#.utf8)
        let cfg = try JSONDecoder.fediHome.decode(ServerConfig.self, from: json)
        XCTAssertEqual(cfg.mediaCategories?.photos.map(\.slug), ["general", "photo-walk"])
        XCTAssertEqual(cfg.mediaCategories?.photos.last?.label, "Photo Walk")
        XCTAssertEqual(cfg.mediaCategories?.videos.count, 1)
    }

    func testServerConfigToleratesMissingMediaCategories() throws {
        // An older instance omits the key entirely — still decodes (nil).
        let cfg = try JSONDecoder.fediHome.decode(
            ServerConfig.self, from: Data(#"{"categories":["note"]}"#.utf8))
        XCTAssertNil(cfg.mediaCategories)
    }
}
