import Foundation
import FediHomeKit

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published private(set) var response: NotificationsResponse?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    var items: [NotificationItem] { response?.items ?? [] }
    var unreadCount: Int { response?.count ?? 0 }

    /// Guards against a stale in-flight load (e.g. the 30s poll) overwriting a newer
    /// one (e.g. mark-all-read) and resurrecting read notifications + the badge.
    private var loadToken = 0

    func load(session: SessionStore) async {
        guard let client = session.client else { return }
        loadToken &+= 1
        let token = loadToken
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await client.notifications()
            guard token == loadToken else { return } // superseded by a newer load
            response = result
        } catch APIError.unauthorized {
            session.reportUnauthorized()
        } catch {
            guard token == loadToken else { return }
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func markAllRead(session: SessionStore) async {
        guard let client = session.client else { return }
        do {
            try await client.markAllNotificationsRead()
            await load(session: session)
        } catch APIError.unauthorized {
            session.reportUnauthorized()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
