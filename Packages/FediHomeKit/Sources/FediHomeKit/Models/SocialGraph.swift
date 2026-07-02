import Foundation

/// `GET /api/graph` — merged fediverse + Bluesky followers/following, plus the
/// block list (newer instances; optional so older servers still decode).
public struct SocialGraph: Codable, Sendable, Equatable {
    public let followers: [GraphPerson]
    public let following: [GraphPerson]
    public let blocked: [BlockedPerson]?
    public let counts: Counts

    public struct Counts: Codable, Sendable, Equatable {
        public let followers: Int
        public let following: Int
        public let blocked: Int?
    }

    public var blockedPeople: [BlockedPerson] { blocked ?? [] }
}

/// An actor the owner has blocked (from the `BlockedActor` table).
public struct BlockedPerson: Codable, Sendable, Identifiable, Equatable {
    public let actorUri: String
    public let handle: String?         // @user@domain, when known
    public let displayName: String?
    public let avatarUrl: String?
    public let createdAt: Date?

    public var id: String { actorUri }
    public var name: String {
        if let displayName, !displayName.isEmpty { return displayName }
        return handle ?? actorUri
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
