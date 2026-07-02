import Foundation
import FediHomeKit

/// The app's sidebar sections — shared so menu commands and the menu-bar item can
/// drive navigation, not just the sidebar.
enum AppSection: Hashable, CaseIterable {
    case feed, notifications, compose, people, messages, myPosts
}

/// App-level navigation state, shared across the window and the menu-bar scene.
@MainActor
final class Navigator: ObservableObject {
    @Published var section: AppSection = .feed
    /// Bumped by the Refresh command; the visible section observes it and reloads.
    @Published private(set) var refreshTick = 0

    func go(_ section: AppSection) { self.section = section }
    func refresh() { refreshTick += 1 }
}

/// Unread counts for the menu-bar item, polled while connected.
@MainActor
final class BadgeModel: ObservableObject {
    @Published private(set) var notificationCount = 0
    @Published private(set) var unreadMessages = 0

    var total: Int { notificationCount + unreadMessages }

    /// Let the visible section keep the badge in sync without an extra round-trip.
    func setNotificationCount(_ value: Int) { notificationCount = value }
    func setUnreadMessages(_ value: Int) { unreadMessages = value }

    func refresh(session: SessionStore) async {
        guard let client = session.client else {
            notificationCount = 0; unreadMessages = 0; return
        }
        if let notifs = try? await client.notifications() { notificationCount = notifs.count }
        if let dms = try? await client.directMessages() {
            unreadMessages = DirectMessagesViewModel.group(dms).filter(\.unread).count
        }
    }
}
