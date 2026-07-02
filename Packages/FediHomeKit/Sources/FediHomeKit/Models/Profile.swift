import Foundation

/// `GET /api/profile?actor=` / `?handle=` — a remote actor's profile detail.
/// `?handle=` on an unknown actor returns a lightweight discovery card
/// (`partial: true`, no bio/header/counts network fetch).
public struct Profile: Codable, Sendable, Equatable, Identifiable {
    public var id: String { actorUri }

    public struct Counts: Codable, Sendable, Equatable {
        /// Best-effort AP collection totals — remotes may hide them.
        public let followers: Int?
        public let following: Int?
        public let posts: Int?
    }

    public let actorUri: String
    public let handle: String          // @user@domain
    public let displayName: String?
    public let avatarUrl: String?
    public let headerUrl: String?
    public let summary: String?        // sanitized HTML bio
    public let url: String             // claimed profile URL (or the actorUri)
    public let counts: Counts
    public let followedByMe: Bool
    public let followsMe: Bool
    public let partial: Bool

    public var name: String {
        if let displayName, !displayName.isEmpty { return displayName }
        return handle
    }
    public var webURL: URL? { URL(string: url) }
}
