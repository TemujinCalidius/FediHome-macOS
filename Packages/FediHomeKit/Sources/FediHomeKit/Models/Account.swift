import Foundation

/// `GET /api/account` — the owner's identity + instance info ("who am I connected as").
public struct Account: Codable, Sendable, Equatable {
    public struct Counts: Codable, Sendable, Equatable {
        public let followers: Int
        public let following: Int
        public let posts: Int
    }

    public let me: String
    public let actor: String
    public let handle: String
    public let domain: String
    public let fediAddress: String
    /// Descriptive fields come straight from the instance's site config; treat as optional
    /// so a blank/absent value never fails the whole connect.
    public let name: String?
    public let authorName: String?
    public let summary: String?
    /// Website "about" bio — distinct from `summary` (the fediverse actor bio).
    /// Optional: older instances don't send these three (added with FediHome#201).
    public let bio: String?
    public let tagline: String?
    public let accentColor: String?
    public let avatar: String
    public let banner: String
    public let counts: Counts

    public var avatarURL: URL? { URL(string: avatar) }
    public var bannerURL: URL? { URL(string: banner) }
    /// Best display name: the site name, else the fedi handle.
    public var displayName: String {
        if let name, !name.isEmpty { return name }
        return handle
    }
}
