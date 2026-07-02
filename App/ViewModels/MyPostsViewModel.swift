import Foundation
import FediHomeKit

@MainActor
final class MyPostsViewModel: ObservableObject {
    enum StatusFilter: String, CaseIterable, Identifiable {
        case all, published, scheduled, draft
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "All"
            case .published: return "Published"
            case .scheduled: return "Scheduled"
            case .draft: return "Drafts"
            }
        }
        var queryValue: String? { self == .all ? nil : rawValue }
    }

    enum TypeFilter: String, CaseIterable, Identifiable {
        case all, note, article, journal, photo, video, audio
        var id: String { rawValue }
        var label: String { self == .all ? "All types" : rawValue.capitalized }
        var queryValue: String? { self == .all ? nil : rawValue }
    }

    @Published var posts: [OwnPost] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var statusFilter: StatusFilter = .all
    @Published var typeFilter: TypeFilter = .all

    private var cursor: String?
    private var reachedEnd = false
    private var loadToken = 0

    func load(session: SessionStore) async {
        guard let client = session.client else { return }
        loadToken &+= 1
        let token = loadToken
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let page = try await client.ownPosts(status: statusFilter.queryValue,
                                                 type: typeFilter.queryValue)
            guard token == loadToken else { return }
            posts = page.posts
            cursor = page.nextCursor
            reachedEnd = page.nextCursor == nil
        } catch APIError.unauthorized {
            session.reportUnauthorized()
        } catch {
            guard token == loadToken else { return }
            errorMessage = Self.friendlyMessage(for: error)
        }
    }

    func loadMoreIfNeeded(current post: OwnPost, session: SessionStore) async {
        guard post.id == posts.last?.id else { return }
        guard let client = session.client, !reachedEnd, !isLoading, !isLoadingMore, let cursor else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await client.ownPosts(cursor: cursor,
                                                 status: statusFilter.queryValue,
                                                 type: typeFilter.queryValue)
            posts.append(contentsOf: page.posts)
            self.cursor = page.nextCursor
            reachedEnd = page.nextCursor == nil
        } catch APIError.unauthorized {
            session.reportUnauthorized()
        } catch {
            errorMessage = Self.friendlyMessage(for: error)
        }
    }

    /// Deletes (or, for a scheduled post, cancels) via Micropub; removes the row on success.
    func delete(_ post: OwnPost, session: SessionStore) async {
        guard let client = session.client else { return }
        let webURL = post.webURL(relativeTo: session.resolvedBaseURL)?.absoluteString ?? post.url
        do {
            try await client.deletePost(url: webURL)
            posts.removeAll { $0.id == post.id }
        } catch APIError.unauthorized {
            session.reportUnauthorized()
        } catch {
            errorMessage = Self.friendlyMessage(for: error)
        }
    }

    private static func friendlyMessage(for error: Error) -> String {
        if case APIError.http(let status, _) = error, status == 404 {
            return "Your instance doesn't support listing posts yet — update FediHome to the latest release."
        }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
