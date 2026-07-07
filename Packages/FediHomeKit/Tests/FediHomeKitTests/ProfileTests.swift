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

final class ProfileUpdateTests: XCTestCase {
    func testUpdateResultDecodes() throws {
        let json = Data("""
        { "success": true, "profile": {
            "authorName": "Samuel", "bio": "About me", "tagline": "Hi",
            "summary": "Fedi bio", "accentColor": "#3b82f6",
            "avatar": "https://fedihome.social/uploads/2026/07/a.webp",
            "banner": "https://fedihome.social/images/banner.webp" } }
        """.utf8)
        let result = try JSONDecoder.fediHome.decode(ProfileUpdateResult.self, from: json)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.profile.authorName, "Samuel")
        XCTAssertEqual(result.profile.accentColor, "#3b82f6")
    }

    func testAccountDecodesWithAndWithoutNewProfileFields() throws {
        let newServer = Data("""
        { "me": "https://f.social", "actor": "https://f.social/ap/actor", "handle": "me",
          "domain": "f.social", "fediAddress": "@me@f.social", "name": "Site",
          "authorName": "Samuel", "summary": "fedi bio", "bio": "site bio",
          "tagline": "hello", "accentColor": "#112233",
          "avatar": "https://f.social/images/avatar.png", "banner": "https://f.social/images/banner.webp",
          "counts": { "followers": 1, "following": 2, "posts": 3 } }
        """.utf8)
        let account = try JSONDecoder.fediHome.decode(Account.self, from: newServer)
        XCTAssertEqual(account.bio, "site bio")
        XCTAssertEqual(account.tagline, "hello")

        let oldServer = Data("""
        { "me": "https://f.social", "actor": "https://f.social/ap/actor", "handle": "me",
          "domain": "f.social", "fediAddress": "@me@f.social", "name": "Site",
          "authorName": "Samuel", "summary": "fedi bio",
          "avatar": "https://f.social/images/avatar.png", "banner": "https://f.social/images/banner.webp",
          "counts": { "followers": 1, "following": 2, "posts": 3 } }
        """.utf8)
        let legacy = try JSONDecoder.fediHome.decode(Account.self, from: oldServer)
        XCTAssertNil(legacy.bio) // older instances still decode
    }
}

final class GraphBlockedTests: XCTestCase {
    func testGraphDecodesWithBlockedList() throws {
        let json = Data("""
        { "followers": [], "following": [],
          "blocked": [{ "actorUri": "https://bad.example/users/troll", "handle": "@troll@bad.example",
                        "displayName": "Troll", "avatarUrl": null, "createdAt": "2026-07-02T10:00:00Z" }],
          "counts": { "followers": 0, "following": 0, "blocked": 1 } }
        """.utf8)
        let graph = try JSONDecoder.fediHome.decode(SocialGraph.self, from: json)
        XCTAssertEqual(graph.blockedPeople.count, 1)
        XCTAssertEqual(graph.blockedPeople.first?.name, "Troll")
        XCTAssertEqual(graph.counts.blocked, 1)
    }

    func testGraphDecodesWithoutBlocked_oldServer() throws {
        let json = Data("""
        { "followers": [], "following": [], "counts": { "followers": 2, "following": 3 } }
        """.utf8)
        let graph = try JSONDecoder.fediHome.decode(SocialGraph.self, from: json)
        XCTAssertTrue(graph.blockedPeople.isEmpty) // optional-decode default
        XCTAssertNil(graph.counts.blocked)
        XCTAssertEqual(graph.counts.following, 3)
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
