import Foundation
import FediHomeKit

@MainActor
final class ThreadViewModel: ObservableObject, PostInteracting {
    @Published var posts: [FediPost] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var actionError: String?

    /// Edits one of our own replies (`edit_reply`, federates an AP Update).
    func editReply(_ post: FediPost, text: String, session: SessionStore) async -> Bool {
        guard let client = session.client else { return false }
        do {
            try await client.editReply(replyId: post.id, content: text)
            return true
        } catch APIError.unauthorized {
            session.reportUnauthorized(); return false
        } catch {
            actionError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func load(rootPost: FediPost, session: SessionStore) async {
        guard let client = session.client else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            posts = try await client.conversation(postId: rootPost.id).thread
        } catch APIError.unauthorized {
            session.reportUnauthorized()
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            if posts.isEmpty {
                errorMessage = message // initial load → full-pane error state
            } else {
                // Refresh after an edit/reply failed: the list still shows stale content,
                // so surface it via the alert instead of failing silently.
                actionError = "Couldn't refresh the thread — your change was sent, but the view may be out of date. (\(message))"
            }
        }
    }
}
