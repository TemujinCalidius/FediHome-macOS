import SwiftUI
import FediHomeKit

struct NotificationsView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var navigator: Navigator
    @EnvironmentObject private var badge: BadgeModel
    @Environment(\.openURL) private var openURL
    @StateObject private var model = NotificationsViewModel()
    @State private var filter: NotificationFilter = .all

    private var filteredItems: [NotificationItem] {
        filter == .all ? model.items : model.items.filter { filter.matches($0.type) }
    }
    /// The newest `unreadCount` items are unread — as a set so filtering doesn't break it.
    private var unreadIDs: Set<String> {
        Set(model.items.prefix(model.unreadCount).map(\.id))
    }

    var body: some View {
        content
            .navigationTitle(title)
            .toolbar {
                Menu {
                    Picker("Filter", selection: $filter) {
                        ForEach(NotificationFilter.allCases) { Text($0.label).tag($0) }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .help("Filter")
                Button {
                    Task {
                        await model.markAllRead(session: session)
                        badge.setNotificationCount(0)
                        badge.markNotificationsSeen(model.items, session: session) // read → never banner
                    }
                } label: {
                    Image(systemName: "checkmark.circle")
                }
                .disabled(model.unreadCount == 0)
                .help("Mark all read")
                Button {
                    Task {
                        await model.load(session: session)
                        badge.setNotificationCount(model.unreadCount)
                        badge.markNotificationsSeen(model.items, session: session)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(model.isLoading)
                .help("Refresh")
            }
            .task {
                // Poll while Notifications is open so new likes/boosts/replies show up on their own.
                while !Task.isCancelled {
                    await model.load(session: session)
                    badge.setNotificationCount(model.unreadCount)
                    // The user is looking at these — don't banner them from the slower badge poll.
                    badge.markNotificationsSeen(model.items, session: session)
                    try? await Task.sleep(for: .seconds(Prefs.notifPollSeconds))
                }
            }
            .onChange(of: navigator.refreshTick) { Task { await model.load(session: session) } }
    }

    private var title: String {
        model.unreadCount > 0 ? "Notifications (\(model.unreadCount))" : "Notifications"
    }

    /// Open the notification's target (the post) or the actor, in the browser.
    /// FediHome returns relative paths (e.g. `/post/slug`, `/timeline`) as well as
    /// absolute URLs, so resolve against the instance base URL (an unresolved
    /// relative URL makes `openURL` fail with paramErr / -50).
    private func open(_ item: NotificationItem) {
        guard let string = item.targetUrl ?? item.actorUrl,
              let url = MediaURL.resolve(string, relativeTo: session.resolvedBaseURL) else { return }
        openURL(url)
    }

    @ViewBuilder private var content: some View {
        if model.isLoading && model.response == nil {
            TopAlignedState { ProgressView("Loading…") }
        } else if let error = model.errorMessage, model.response == nil {
            TopAlignedState {
                ContentUnavailableView {
                    Label("Couldn't load notifications", systemImage: "bell.slash")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await model.load(session: session) } }
                }
            }
        } else if model.items.isEmpty {
            TopAlignedState {
                ContentUnavailableView("No notifications", systemImage: "bell",
                                       description: Text("You're all caught up."))
            }
        } else if filteredItems.isEmpty {
            TopAlignedState {
                ContentUnavailableView("No \(filter.label.lowercased())", systemImage: "line.3.horizontal.decrease.circle")
            }
        } else {
            List(filteredItems) { item in
                NotificationRow(item: item, baseURL: session.resolvedBaseURL, isUnread: unreadIDs.contains(item.id))
                    .contentShape(Rectangle())
                    .onTapGesture { open(item) }
            }
            .listStyle(.inset)
            .refreshable { await model.load(session: session) }
        }
    }
}

enum NotificationFilter: String, CaseIterable, Identifiable {
    case all, mentions, likes, boosts, follows, dms

    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: return "All"
        case .mentions: return "Replies & mentions"
        case .likes: return "Likes"
        case .boosts: return "Boosts"
        case .follows: return "Follows"
        case .dms: return "Messages"
        }
    }

    func matches(_ type: NotificationItem.Kind) -> Bool {
        switch self {
        case .all: return true
        case .mentions: return type == .reply || type == .comment
        case .likes: return type == .like
        case .boosts: return type == .boost
        case .follows: return type == .follow
        case .dms: return type == .dm
        }
    }
}

struct NotificationRow: View {
    let item: NotificationItem
    var baseURL: URL?
    var isUnread = false

    private var avatarURL: URL? {
        guard let raw = item.avatarUrl else { return nil }
        if let baseURL { return MediaURL.resolve(raw, relativeTo: baseURL) }
        return URL(string: raw)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                AsyncAvatar(url: avatarURL, size: 36)
                Image(systemName: symbol)
                    .font(.caption2)
                    .padding(3)
                    .background(.background, in: Circle())
                    .foregroundStyle(.tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.actor).font(.callout).bold().lineLimit(1)
                Text(item.summary).font(.callout).foregroundStyle(.secondary).lineLimit(3)
                Text(item.createdAt, format: .relative(presentation: .named))
                    .font(.caption).foregroundStyle(.tertiary)
            }
            Spacer()
            if isUnread {
                Circle().fill(.tint).frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }

    private var symbol: String {
        switch item.type {
        case .like: return "heart.fill"
        case .boost: return "arrow.2.squarepath"
        case .reply: return "arrowshape.turn.up.left.fill"
        case .follow: return "person.badge.plus"
        case .comment: return "text.bubble.fill"
        case .dm: return "envelope.fill"
        case .update: return "gearshape.fill"
        case .unknown: return "bell.fill"
        }
    }
}
