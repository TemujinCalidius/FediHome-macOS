import Foundation
import FediHomeKit

@MainActor
final class FeedViewModel: ObservableObject, PostInteracting {
    @Published var posts: [FediPost] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var actionError: String?

    /// Timeline filters passed to `GET /api/feed`.
    @Published var includeReplies = false
    @Published var includeBoosts = true

    private var cursor: String?
    private var reachedEnd = false
    /// Guards concurrent first-page loads (toolbar Refresh / pull-to-refresh / ⌘R)
    /// from a stale response overwriting a newer one.
    private var loadToken = 0

    func loadFirst(session: SessionStore) async {
        guard let client = session.client else { return }
        loadToken &+= 1
        let token = loadToken
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let page = try await client.feed(replies: includeReplies, boosts: includeBoosts)
            guard token == loadToken else { return } // superseded by a newer load
            posts = page.posts
            cursor = page.nextCursor
            reachedEnd = page.nextCursor == nil
        } catch APIError.unauthorized {
            session.reportUnauthorized()
        } catch {
            guard token == loadToken else { return }
            errorMessage = Self.message(for: error)
        }
    }

    /// Called as each row appears; pages when the last row is reached.
    func loadMoreIfNeeded(current post: FediPost, session: SessionStore) async {
        guard post.id == posts.last?.id else { return }
        guard let client = session.client, !reachedEnd, !isLoading, !isLoadingMore, let cursor else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await client.feed(cursor: cursor, replies: includeReplies, boosts: includeBoosts)
            posts.append(contentsOf: page.posts)
            self.cursor = page.nextCursor
            reachedEnd = page.nextCursor == nil
        } catch APIError.unauthorized {
            session.reportUnauthorized()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
