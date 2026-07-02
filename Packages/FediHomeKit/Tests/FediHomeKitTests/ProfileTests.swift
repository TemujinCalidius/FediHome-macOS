import XCTest
@testable import FediHomeKit

final class ProfileTests: XCTestCase {
    func testFullProfileDecodes() throws {
        let json = Data("""
        { "actorUri": "https://mastodon.social/users/alice", "handle": "@alice@mastodon.social",
          "displayName": "Alice", "avatarUrl": "https://files.mastodon.social/a.png",
          "headerUrl": "https://files.mastodon.social/h.png",
          "summary": "<p>Photographer. <a href=\\"https://mastodon.social/tags/fedi\\" class=\\"hashtag\\">#fedi</a></p>",
          "url": "https://mastodon.social/@alice",
          "counts": { "followers": 1200, "following": 340, "posts": 5678 },
          "followedByMe": true, "followsMe": false, "partial": false }
        """.utf8)
        let profile = try JSONDecoder.fediHome.decode(Profile.self, from: json)
        XCTAssertEqual(profile.name, "Alice")
        XCTAssertEqual(profile.counts.followers, 1200)
        XCTAssertTrue(profile.followedByMe)
        XCTAssertFalse(profile.partial)
        XCTAssertEqual(profile.webURL?.absoluteString, "https://mastodon.social/@alice")
        XCTAssertEqual(profile.id, profile.actorUri)
    }

    func testPartialDiscoveryCardDecodes() throws {
        let json = Data("""
        { "actorUri": "https://example.social/users/bob", "handle": "@bob@example.social",
          "displayName": null, "avatarUrl": null, "headerUrl": null, "summary": null,
          "url": "https://example.social/users/bob",
          "counts": { "followers": null, "following": null, "posts": null },
          "followedByMe": false, "followsMe": false, "partial": true }
        """.utf8)
        let profile = try JSONDecoder.fediHome.decode(Profile.self, from: json)
        XCTAssertTrue(profile.partial)
        XCTAssertNil(profile.counts.posts)
        XCTAssertEqual(profile.name, "@bob@example.social") // falls back to handle
    }

    func testProfileTargetParsesHandle() {
        let profile = Profile(
            actorUri: "https://m.social/users/carol", handle: "@carol@m.social",
            displayName: "Carol", avatarUrl: nil, headerUrl: nil, summary: nil,
            url: "https://m.social/@carol",
            counts: .init(followers: nil, following: nil, posts: nil),
            followedByMe: false, followsMe: false, partial: true
        )
        // ProfileTarget lives in the app target; here we just sanity-check the model's
        // handle format contract it relies on ("@user@domain" → 2 parts).
        let parts = profile.handle.split(separator: "@", omittingEmptySubsequences: true)
        XCTAssertEqual(parts.count, 2)
        XCTAssertEqual(String(parts[0]), "carol")
        XCTAssertEqual(String(parts[1]), "m.social")
    }
}

// Memberwise init for the test above (the model is decode-only in production).
private extension Profile {
    init(actorUri: String, handle: String, displayName: String?, avatarUrl: String?,
         headerUrl: String?, summary: String?, url: String, counts: Counts,
         followedByMe: Bool, followsMe: Bool, partial: Bool) {
        let json: [String: Any?] = [
            "actorUri": actorUri, "handle": handle, "displayName": displayName,
            "avatarUrl": avatarUrl, "headerUrl": headerUrl, "summary": summary, "url": url,
            "counts": ["followers": counts.followers, "following": counts.following, "posts": counts.posts],
            "followedByMe": followedByMe, "followsMe": followsMe, "partial": partial,
        ]
        let data = try! JSONSerialization.data(withJSONObject: json.mapValues { $0 ?? NSNull() })
        self = try! JSONDecoder.fediHome.decode(Profile.self, from: data)
    }
}
