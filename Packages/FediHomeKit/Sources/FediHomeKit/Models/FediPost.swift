import Foundation

/// A single item in `GET /api/feed`. Mirrors the server's `FediPost` row exactly
/// (the feed route spreads the whole record, re-sanitizing `contentHtml`).
public struct FediPost: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let actorUri: String
    public let apId: String
    /// Plain-text rendering of the post.
    public let content: String
    /// Sanitized HTML rendering (may be null).
    public let contentHtml: String?
    /// Parallel arrays: `mediaTypes[i]` ("image"/"video") describes `mediaUrls[i]`.
    public let mediaUrls: [String]
    public let mediaTypes: [String]
    public let username: String
    public let domain: String
    public let displayName: String?
    public let avatarUrl: String?
    public let publishedAt: Date
    public let createdAt: Date
    public let isOutgoing: Bool

    // Boost/repost attribution
    public let boostedBy: String?
    public let boostedByName: String?

    // Threading
    public let inReplyTo: String?
    public let conversationId: String?

    // Link-preview embed
    public let embedUrl: String?
    public let embedTitle: String?
    public let embedDescription: String?
    public let embedImage: String?
    public let embedSiteName: String?

    // Cached interaction counts (null = never fetched)
    public let likeCount: Int?
    public let boostCount: Int?
    public let replyCount: Int?
    public let countsFetchedAt: Date?

    // Owner's own interaction state
    public let likedByMe: Bool
    public let boostedByMe: Bool

    // MARK: Convenience

    /// `@username@domain`.
    public var fediHandle: String { "@\(username)@\(domain)" }
    /// Author's display name, falling back to the username.
    public var authorName: String {
        if let displayName, !displayName.isEmpty { return displayName }
        return username
    }
    public var avatarURL: URL? { avatarUrl.flatMap(URL.init(string:)) }
    public var isBoost: Bool { boostedBy != nil }
    public var isReply: Bool { inReplyTo != nil }

    /// Media as typed pairs for rendering.
    public struct Media: Sendable, Equatable, Identifiable {
        public enum Kind: Sendable, Equatable { case image, video, other(String) }
        public let url: URL
        public let kind: Kind
        public var id: String { url.absoluteString }
    }

    public var media: [Media] {
        zip(mediaUrls, mediaTypes.appendingIfShorter(than: mediaUrls, with: "image"))
            .compactMap { urlString, type in
                guard let url = URL(string: urlString) else { return nil }
                let kind: Media.Kind
                switch type {
                case "image": kind = .image
                case "video": kind = .video
                default: kind = .other(type)
                }
                return Media(url: url, kind: kind)
            }
    }
}

private extension Array where Element == String {
    /// Pads `self` up to `other`'s count so `zip` doesn't drop trailing media.
    func appendingIfShorter(than other: [String], with fallback: String) -> [String] {
        guard count < other.count else { return self }
        return self + Array(repeating: fallback, count: other.count - count)
    }
}
