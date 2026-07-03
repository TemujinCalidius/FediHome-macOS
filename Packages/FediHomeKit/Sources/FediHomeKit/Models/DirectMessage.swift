import Foundation

/// `GET /api/dms` — one direct message (fediverse or Bluesky).
public struct DirectMessage: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let source: String            // "fedi" | "bluesky"
    public let senderUri: String         // actorUri (fedi) or DID (bsky)
    public let senderHandle: String
    public let senderName: String?
    public let senderAvatar: String?
    public let content: String
    public let contentHtml: String?
    public let apId: String?
    /// Bluesky conversation id — required to reply in a bsky thread.
    public let bskyConvoId: String?
    public let conversationKey: String   // "fedi:{actorUri}" | "bsky:{did}"
    public let isOutgoing: Bool
    public let deliveredAt: Date?
    public let deliveryError: String?
    public let createdAt: Date

    public var isFedi: Bool { source == "fedi" }
    public var senderAvatarURL: URL? { senderAvatar.flatMap(URL.init(string:)) }
    public var senderDisplayName: String {
        if let senderName, !senderName.isEmpty { return senderName }
        return senderHandle
    }
}

public struct DirectMessagesResponse: Codable, Sendable, Equatable {
    public let messages: [DirectMessage]
    /// Last-read timestamp per `conversationKey`.
    public let readState: [String: Date]
}
