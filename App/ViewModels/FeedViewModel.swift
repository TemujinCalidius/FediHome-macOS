import Foundation
import FediHomeKit

@MainActor
final class FeedViewModel: ObservableObject, PostInteracting {
    @Published var posts: [FediPost] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var actionError: String?

    private var cursor: String?
    private var reachedEnd = false

    func loadFirst(session: SessionStore) async {
        guard let client = session.client else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let page = try await client.feed()
            posts = page.posts
            cursor = page.nextCursor
            reachedEnd = page.nextCursor == nil
        } catch APIError.unauthorized {
            session.reportUnauthorized()
        } catch {
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
            let page = try await client.feed(cursor: cursor)
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
