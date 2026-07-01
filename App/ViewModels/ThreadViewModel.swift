import Foundation
import FediHomeKit

@MainActor
final class ThreadViewModel: ObservableObject, PostInteracting {
    @Published var posts: [FediPost] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var actionError: String?

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
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
