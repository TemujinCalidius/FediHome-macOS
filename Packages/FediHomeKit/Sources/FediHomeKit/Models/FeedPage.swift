import Foundation

/// `GET /api/feed` — one page of the private timeline.
public struct FeedPage: Codable, Sendable, Equatable {
    public let posts: [FediPost]
    /// ISO-8601 `publishedAt` of the last item to pass as the next `cursor`,
    /// or `nil` when there are no more pages.
    public let nextCursor: String?
}
