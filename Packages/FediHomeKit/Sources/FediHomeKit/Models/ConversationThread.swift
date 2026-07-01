import Foundation

/// `GET /api/conversation?postId=<local id>` — the full thread (ancestors + root +
/// descendants), ordered, each a complete `FediPost` with interaction state.
public struct ConversationThread: Codable, Sendable, Equatable {
    public let thread: [FediPost]
}
