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
    /// Setters and newer refreshes supersede any in-flight poll (stale-response guard).
    private var refreshToken = 0

    /// Let the visible section keep the badge in sync without an extra round-trip.
    func setNotificationCount(_ value: Int) {
        refreshToken &+= 1
        notificationCount = value
        redrawDockBadge()
    }

    func setUnreadMessages(_ value: Int) {
        refreshToken &+= 1
        unreadMessages = value
        redrawDockBadge()
    }

    /// Zeroes everything (disconnect / not-connected).
    func reset() {
        refreshToken &+= 1
        notificationCount = 0
        unreadMessages = 0
        redrawDockBadge()
    }

    func refresh(session: SessionStore) async {
        guard let client = session.client else { reset(); return }
        refreshToken &+= 1
        let token = refreshToken
        let host = session.resolvedBaseURL.host ?? "default"
        let notifs = try? await client.notifications()
        let dms = try? await client.directMessages()
        guard token == refreshToken else { return } // superseded (e.g. mark-all-read setter)
        if let notifs {
            notificationCount = notifs.count
            announceNewNotifications(notifs.items, host: host)
        }
        if let dms {
            unreadMessages = DirectMessagesViewModel.group(dms).filter(\.unread).count
            announceNewDMs(dms.messages, host: host)
        }
        redrawDockBadge()
    }

    // MARK: Native banners — ID-based, per-instance dedupe
    // (IDs, not timestamps: late-arriving federated items still announce, and clock
    // skew can't suppress or replay. Keyed by instance host so switching accounts
    // neither blasts the other instance's backlog nor swallows new items.)

    /// The section views see items sooner than this poll — recording them as seen
    /// prevents banners for things the user is already looking at / has read.
    func markNotificationsSeen(_ items: [NotificationItem], session: SessionStore) {
        let host = session.resolvedBaseURL.host ?? "default"
        _ = recordFresh(key: "seenNotifIds|\(host)", ids: items.filter { $0.type != .dm }.map(\.id))
    }

    func markDMsSeen(_ messages: [DirectMessage], session: SessionStore) {
        let host = session.resolvedBaseURL.host ?? "default"
        _ = recordFresh(key: "seenDMIds|\(host)", ids: messages.filter { !$0.isOutgoing }.map(\.id))
    }

    private func announceNewNotifications(_ items: [NotificationItem], host: String) {
        // An incoming DM also appears as a `dm` notification item — the DM path owns
        // that banner, otherwise one message would notify twice.
        let relevant = items.filter { $0.type != .dm }
        let fresh = recordFresh(key: "seenNotifIds|\(host)", ids: relevant.map(\.id))
        guard Prefs.notifyBanners, !fresh.isEmpty else { return }
        if fresh.count == 1, let item = relevant.first(where: { $0.id == fresh[0] }) {
            NotificationManager.shared.post(title: item.actor,
                                            body: item.summary.isEmpty ? "New activity" : item.summary,
                                            section: .notifications)
        } else {
            NotificationManager.shared.post(title: "FediHome",
                                            body: "\(fresh.count) new notifications",
                                            section: .notifications)
        }
    }

    private func announceNewDMs(_ messages: [DirectMessage], host: String) {
        let incoming = messages.filter { !$0.isOutgoing }
        let fresh = recordFresh(key: "seenDMIds|\(host)", ids: incoming.map(\.id))
        guard Prefs.notifyBanners, !fresh.isEmpty else { return }
        if fresh.count == 1, let message = incoming.first(where: { $0.id == fresh[0] }) {
            let source = (message.contentHtml?.isEmpty == false) ? message.contentHtml! : message.content
            let snippet = String(FediHTML.plainText(from: source).prefix(120))
            NotificationManager.shared.post(title: "Message from \(message.senderDisplayName)",
                                            body: snippet, section: .messages)
        } else {
            NotificationManager.shared.post(title: "FediHome",
                                            body: "\(fresh.count) new messages", section: .messages)
        }
    }

    /// Records `ids` as seen and returns the ones that were new. First call for a key
    /// seeds the whole set without reporting anything (no history replay). Runs even
    /// when banners are off, so re-enabling never blasts a backlog. Bounded store.
    private func recordFresh(key: String, ids: [String]) -> [String] {
        let defaults = UserDefaults.standard
        let cap = 800
        guard let seenArray = defaults.stringArray(forKey: key) else {
            defaults.set(Array(ids.prefix(cap)), forKey: key)
            return []
        }
        let seen = Set(seenArray)
        let fresh = ids.filter { !seen.contains($0) }
        if !fresh.isEmpty {
            let idSet = Set(ids)
            let merged = ids + seenArray.filter { !idSet.contains($0) }
            defaults.set(Array(merged.prefix(cap)), forKey: key)
        }
        return fresh
    }

    /// Mirrors the unread total onto the Dock icon (the classic red count bubble).
    /// Also called when the Settings toggle flips, so it applies immediately.
    func redrawDockBadge() {
        NSApp.dockTile.badgeLabel = (Prefs.showDockBadge && total > 0) ? String(total) : nil
    }
}
