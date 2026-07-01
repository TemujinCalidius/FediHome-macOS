import Foundation
import FediHomeKit

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published private(set) var response: NotificationsResponse?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    var items: [NotificationItem] { response?.items ?? [] }
    var unreadCount: Int { response?.count ?? 0 }

    func load(session: SessionStore) async {
        guard let client = session.client else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            response = try await client.notifications()
        } catch APIError.unauthorized {
            session.reportUnauthorized()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
