import Foundation
import AppKit
import FediHomeKit

/// The app's sidebar sections — shared so menu commands and the menu-bar item can
/// drive navigation, not just the sidebar.
enum AppSection: String, Hashable, CaseIterable {
    case feed, notifications, compose, people, messages, myPosts
}

/// App-level navigation state, shared across the window and the menu-bar scene.
/// The selected section persists across launches.
@MainActor
final class Navigator: ObservableObject {
    private static let sectionKey = "lastSection"

    @Published var section: AppSection {
        didSet { UserDefaults.standard.set(section.rawValue, forKey: Self.sectionKey) }
    }
    /// Bumped by the Refresh command; the visible section observes it and reloads.
    @Published private(set) var refreshTick = 0

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.sectionKey)
        section = Prefs.rememberSection ? (saved.flatMap(AppSection.init(rawValue:)) ?? .feed) : .feed
    }

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
    func setNotificationCount(_ value: Int) { notificationCount = value; redrawDockBadge() }
    func setUnreadMessages(_ value: Int) { unreadMessages = value; redrawDockBadge() }

    func refresh(session: SessionStore) async {
        guard let client = session.client else {
            notificationCount = 0; unreadMessages = 0
            redrawDockBadge()
            return
        }
        if let notifs = try? await client.notifications() {
            notificationCount = notifs.count
            announceNewNotifications(notifs.items)
        }
        if let dms = try? await client.directMessages() {
            unreadMessages = DirectMessagesViewModel.group(dms).filter(\.unread).count
            announceNewDMs(dms.messages)
        }
        redrawDockBadge()
    }

    // MARK: Native banners (new-item detection via persisted watermarks)

    private static let notifWatermarkKey = "lastNotifiedNotifAt"
    private static let dmWatermarkKey = "lastNotifiedDMAt"

    private func announceNewNotifications(_ items: [NotificationItem]) {
        guard let fresh = advanceWatermark(Self.notifWatermarkKey,
                                           dates: items.map(\.createdAt),
                                           matching: items, by: \.createdAt) else { return }
        if fresh.count == 1, let item = fresh.first {
            NotificationManager.shared.post(title: item.actor,
                                            body: item.summary ?? "New activity",
                                            section: .notifications)
        } else {
            NotificationManager.shared.post(title: "FediHome",
                                            body: "\(fresh.count) new notifications",
                                            section: .notifications)
        }
    }

    private func announceNewDMs(_ messages: [DirectMessage]) {
        let incoming = messages.filter { !$0.isOutgoing }
        guard let fresh = advanceWatermark(Self.dmWatermarkKey,
                                           dates: incoming.map(\.createdAt),
                                           matching: incoming, by: \.createdAt) else { return }
        if fresh.count == 1, let message = fresh.first {
            let source = (message.contentHtml?.isEmpty == false) ? message.contentHtml! : message.content
            let snippet = String(FediHTML.plainText(from: source).prefix(120))
            NotificationManager.shared.post(title: "Message from \(message.senderDisplayName)",
                                            body: snippet, section: .messages)
        } else {
            NotificationManager.shared.post(title: "FediHome",
                                            body: "\(fresh.count) new messages", section: .messages)
        }
    }

    /// Returns the items newer than the stored watermark and advances it — or nil when
    /// nothing should be announced. First run seeds the watermark without announcing
    /// (no history replay); when banners are off the watermark still advances so
    /// re-enabling doesn't blast the backlog.
    private func advanceWatermark<T>(_ key: String, dates: [Date],
                                     matching items: [T], by date: KeyPath<T, Date>) -> [T]? {
        guard let newest = dates.max() else { return nil }
        let defaults = UserDefaults.standard
        guard let watermark = defaults.object(forKey: key) as? Date else {
            defaults.set(newest, forKey: key)
            return nil
        }
        guard newest > watermark else { return nil }
        defaults.set(newest, forKey: key)
        guard Prefs.notifyBanners else { return nil }
        return items.filter { $0[keyPath: date] > watermark }
    }

    /// Mirrors the unread total onto the Dock icon (the classic red count bubble).
    /// Also called when the Settings toggle flips, so it applies immediately.
    func redrawDockBadge() {
        NSApp.dockTile.badgeLabel = (Prefs.showDockBadge && total > 0) ? String(total) : nil
    }
}
