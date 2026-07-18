import Foundation

/// One of the owner's own posts from `GET /api/posts` — the backing data for a
/// "My Posts" content manager (includes drafts and scheduled posts, unlike the feed).
public struct OwnPost: Codable, Sendable, Identifiable, Equatable {
    public struct Counts: Codable, Sendable, Equatable {
        public let likes: Int
        public let boosts: Int
    }

    /// Counts of attached media files (not URLs).
    public struct MediaSummary: Codable, Sendable, Equatable {
        public let photos: Int
        public let videos: Int
        public let audio: Int
        public var isEmpty: Bool { photos == 0 && videos == 0 && audio == 0 }
    }

    public enum Status: String, Codable, Sendable {
        case published, scheduled, draft
    }

    public let slug: String
    /// Relative (`/post/<slug>`) — resolve against the instance base URL.
    public let url: String
    public let title: String?
    public let excerpt: String?
    /// Markup-stripped body preview (≤200 chars) from `GET /api/posts` (server v1.15.0+).
    /// Optional so pre-v1.15.0 instances still decode; `""` when the post is genuinely empty.
    public let preview: String?
    public let category: String       // note | article | journal
    /// Derived kind: media takes precedence ("photo"/"video"/"audio"), else the category.
    public let type: String
    public let status: Status
    public let published: Bool
    public let publishedAt: Date
    public let updatedAt: Date
    public let scheduledFor: Date?
    public let counts: Counts
    public let media: MediaSummary
    /// The database id `/api/compose editingPostId` needs (FediHome#202). Optional so
    /// older instances that don't send it still decode — editing is gated on it.
    public let serverId: String?

    public var id: String { slug }

    enum CodingKeys: String, CodingKey {
        case slug, url, title, excerpt, preview, category, type, status, published
        case publishedAt, updatedAt, scheduledFor, counts, media
        case serverId = "id"
    }

    /// Display title: the title, else a trimmed excerpt, else the body preview, else a placeholder.
    /// Promoting `preview` here lets a title-less microblog note show its body in "My Posts"
    /// instead of a bare "Untitled note".
    public var displayTitle: String {
        if let title, !title.isEmpty { return title }
        if let excerpt, !excerpt.isEmpty { return excerpt }
        if let preview, !preview.isEmpty { return preview }
        return "Untitled \(category)"
    }

    public func webURL(relativeTo base: URL) -> URL? {
        MediaURL.resolve(url, relativeTo: base)
    }
}

public struct OwnPostsPage: Codable, Sendable, Equatable {
    public let posts: [OwnPost]
    public let nextCursor: String?
}
