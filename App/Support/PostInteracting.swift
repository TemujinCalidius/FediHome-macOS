import Foundation
import FediHomeKit

/// Shared like/boost/reply/counts behavior for any view model that holds a mutable
/// list of `FediPost` (the feed and a thread). Optimistically flips state and reverts
/// on failure; routes 401 to `SessionStore.reportUnauthorized()`.
@MainActor
protocol PostInteracting: AnyObject {
    var posts: [FediPost] { get set }
    var actionError: String? { get set }
}

extension PostInteracting {
    func toggleLike(_ post: FediPost, session: SessionStore) async {
        guard let client = session.client, let i = index(of: post) else { return }
        let previous = posts[i].likedByMe
        posts[i].likedByMe.toggle()
        do {
            if previous {
                try await client.unlike(postApId: post.apId, targetInbox: post.fallbackInboxURL)
            } else {
                try await client.like(postApId: post.apId, targetInbox: post.fallbackInboxURL)
            }
        } catch {
            if let j = index(of: post) { posts[j].likedByMe = previous } // revert
            handle(error, session: session)
        }
    }

    func toggleBoost(_ post: FediPost, session: SessionStore) async {
        guard let client = session.client, let i = index(of: post) else { return }
        let previous = posts[i].boostedByMe
        posts[i].boostedByMe.toggle()
        do {
            if previous {
                try await client.unboost(postApId: post.apId, targetInbox: post.fallbackInboxURL)
            } else {
                try await client.boost(postApId: post.apId, targetInbox: post.fallbackInboxURL)
            }
        } catch {
            if let j = index(of: post) { posts[j].boostedByMe = previous } // revert
            handle(error, session: session)
        }
    }

    func loadCounts(_ post: FediPost, session: SessionStore) async {
        guard let client = session.client else { return }
        do {
            let counts = try await client.postCounts(postId: post.id)
            if let j = index(of: post) {
                posts[j].likeCount = counts.likeCount
                posts[j].boostCount = counts.boostCount
                posts[j].replyCount = counts.replyCount
                posts[j].countsFetchedAt = counts.countsFetchedAt ?? Date()
            }
        } catch {
            handle(error, session: session)
        }
    }

    /// Sends a reply; returns whether it succeeded (so the composer can dismiss).
    func sendReply(to post: FediPost, text: String, crosspostBluesky: Bool, session: SessionStore) async -> Bool {
        guard let client = session.client else { return false }
        do {
            try await client.reply(
                content: text,
                inReplyTo: post.interactionApId,
                targetInbox: post.fallbackInboxURL,
                actorUri: post.actorUri,
                mentionHandle: post.replyMentionHandle,
                crosspostBluesky: crosspostBluesky
            )
            return true
        } catch {
            handle(error, session: session)
            return false
        }
    }

    private func index(of post: FediPost) -> Int? {
        posts.firstIndex { $0.id == post.id }
    }

    private func handle(_ error: Error, session: SessionStore) {
        if case APIError.unauthorized = error {
            session.reportUnauthorized()
        } else {
            actionError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
