import Foundation

/// `POST /api/fedi-post-counts` — lazily-fetched interaction counts for a post.
public struct PostCounts: Codable, Sendable, Equatable {
    public let likeCount: Int?
    public let boostCount: Int?
    public let replyCount: Int?
    public let countsFetchedAt: Date?
}
