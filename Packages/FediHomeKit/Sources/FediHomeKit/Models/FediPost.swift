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

    // Cached interaction counts (null = never fetched). Mutable so the UI can fill them
    // in from `POST /api/fedi-post-counts` without refetching the whole feed.
    public var likeCount: Int?
    public var boostCount: Int?
    public var replyCount: Int?
    public var countsFetchedAt: Date?

    // Owner's own interaction state — mutable for optimistic like/boost toggles.
    public var likedByMe: Bool
    public var boostedByMe: Bool

    // MARK: Convenience

    /// `@username@domain`.
    public var fediHandle: String { "@\(username)@\(domain)" }
    /// Author's display name, falling back to the username.
    public var authorName: String {
        if let displayName, !displayName.isEmpty { return displayName }
        return username
    }
    public var avatarURL: URL? { avatarUrl.flatMap(URL.init(string:)) }
    public func avatarURL(relativeTo base: URL) -> URL? {
        avatarUrl.flatMap { MediaURL.resolve($0, relativeTo: base) }
    }
    public var isBoost: Bool { boostedBy != nil }
    public var isReply: Bool { inReplyTo != nil }

    // MARK: Interaction wiring

    /// Fallback recipient inbox for like/boost/reply. The server prefers to resolve the
    /// real inbox from `actorUri`; this Mastodon-style guess is only used if that fails.
    public var fallbackInboxURL: String { "https://\(domain)/users/\(username)/inbox" }
    /// The @-mention a reply prefixes / the server strips if duplicated.
    public var replyMentionHandle: String { fediHandle }

    /// The **original** post apId, resolving a boosted row's synthetic
    /// `boost:<actorUri>:<originalApId>` (mirrors the server's `^boost:.*:(https?://.*)$`,
    /// greedy → the last http(s) segment).
    ///
    /// Use this for **reply threading** (`inReplyTo`) and **sharing** — where the original
    /// URL is what matters. Do NOT use it for like/boost: the server persists
    /// `likedByMe`/`boostedByMe` keyed by the *row's* apId, so those must send `apId`
    /// (the synthetic id) or the state won't stick to the boost row on reload.
    public var interactionApId: String {
        guard apId.hasPrefix("boost:") else { return apId }
        let pattern = "^boost:.*:(https?://.*)$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: apId, range: NSRange(apId.startIndex..., in: apId)),
              let range = Range(match.range(at: 1), in: apId) else { return apId }
        return String(apId[range])
    }

    /// Canonical link to share (the original post's ActivityPub id, when it's a web URL).
    public var shareURL: URL? {
        guard let url = URL(string: interactionApId), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return url
    }

    // MARK: Media

    public struct Media: Sendable, Equatable, Identifiable {
        public enum Kind: Sendable, Equatable {
            case image
            case video           // inline-playable direct file
            case link            // external/streaming page — open in browser
        }
        public let url: URL
        public let kind: Kind
        public var id: String { url.absoluteString }
    }

    /// Typed media with URLs resolved against the instance `base` (relative proxied
    /// paths become absolute) and each item classified image / inline-video / link.
    public func media(relativeTo base: URL) -> [Media] {
        let types = mediaTypes.count >= mediaUrls.count
            ? mediaTypes
            : mediaTypes + Array(repeating: "image", count: mediaUrls.count - mediaTypes.count)
        return zip(mediaUrls, types).compactMap { rawURL, type in
            guard let url = MediaURL.resolve(rawURL, relativeTo: base) else { return nil }
            let kind: Media.Kind
            switch type {
            case "image": kind = .image
            case "video": kind = MediaURL.isDirectVideoFile(url, instanceHost: base.host) ? .video : .link
            default: kind = .link
            }
            return Media(url: url, kind: kind)
        }
    }

    // MARK: Embed

    public struct EmbedCard: Sendable, Equatable {
        public let url: URL
        public let title: String?
        public let description: String?
        public let imageURL: URL?
        public let siteName: String?
        public var displaySite: String { siteName ?? url.host ?? url.absoluteString }
    }

    /// A link-preview card, shown (matching the web) only when there's an embed URL and
    /// at least a title or description. `embedImage` is resolved against `base`.
    public func embedCard(relativeTo base: URL) -> EmbedCard? {
        guard let embedUrl, let url = URL(string: embedUrl) else { return nil }
        let hasText = (embedTitle?.isEmpty == false) || (embedDescription?.isEmpty == false)
        guard hasText else { return nil }
        return EmbedCard(
            url: url,
            title: embedTitle,
            description: embedDescription,
            imageURL: embedImage.flatMap { MediaURL.resolve($0, relativeTo: base) },
            siteName: embedSiteName
        )
    }
}
