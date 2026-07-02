import Foundation

/// `GET /api/graph` — merged fediverse + Bluesky followers/following.
public struct SocialGraph: Codable, Sendable, Equatable {
    public let followers: [GraphPerson]
    public let following: [GraphPerson]
    public let counts: Counts

    public struct Counts: Codable, Sendable, Equatable {
        public let followers: Int
        public let following: Int
    }
}

public struct GraphPerson: Codable, Sendable, Identifiable, Equatable {
    public let source: String            // "fedi" | "bsky"
    public let id: String
    public let actorUri: String?         // fedi
    public let username: String?         // fedi
    public let domain: String?           // fedi
    public let did: String?              // bsky
    public let handle: String?           // bsky handle
    public let displayName: String?
    public let avatarUrl: String?
    public let createdAt: Date?

    public var isFedi: Bool { source == "fedi" }

    /// `@user@domain` for fedi, else the Bluesky handle.
    public var fediHandle: String? {
        if let username, let domain { return "@\(username)@\(domain)" }
        return handle
    }

    public var name: String {
        if let displayName, !displayName.isEmpty { return displayName }
        return fediHandle ?? username ?? handle ?? "Unknown"
    }

    public var avatarURL: URL? { avatarUrl.flatMap(URL.init(string:)) }
}
