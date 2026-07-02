import SwiftUI
import FediHomeKit

struct NotificationsView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var navigator: Navigator
    @EnvironmentObject private var badge: BadgeModel
    @Environment(\.openURL) private var openURL
    @StateObject private var model = NotificationsViewModel()

    var body: some View {
        content
            .navigationTitle(title)
            .toolbar {
                Button {
                    Task { await model.markAllRead(session: session); badge.setNotificationCount(0) }
                } label: {
                    Image(systemName: "checkmark.circle")
                }
                .disabled(model.unreadCount == 0)
                .help("Mark all read")
                Button {
                    Task { await model.load(session: session) }
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
                    try? await Task.sleep(for: .seconds(30))
                }
            }
            .onChange(of: navigator.refreshTick) { Task { await model.load(session: session) } }
    }

    private var title: String {
        model.unreadCount > 0 ? "Notifications (\(model.unreadCount))" : "Notifications"
    }

    /// Open the notification's target (the post) or the actor, in the browser.
    private func open(_ item: NotificationItem) {
        if let string = item.targetUrl ?? item.actorUrl, let url = URL(string: string) {
            openURL(url)
        }
    }

    @ViewBuilder private var content: some View {
        if model.isLoading && model.response == nil {
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = model.errorMessage, model.response == nil {
            ContentUnavailableView {
                Label("Couldn't load notifications", systemImage: "bell.slash")
            } description: {
                Text(error)
            } actions: {
                Button("Retry") { Task { await model.load(session: session) } }
            }
        } else if model.items.isEmpty {
            ContentUnavailableView("No notifications", systemImage: "bell",
                                   description: Text("You're all caught up."))
        } else {
            List(Array(model.items.enumerated()), id: \.element.id) { index, item in
                NotificationRow(item: item, isUnread: index < model.unreadCount)
                    .contentShape(Rectangle())
                    .onTapGesture { open(item) }
            }
            .listStyle(.inset)
            .refreshable { await model.load(session: session) }
        }
    }
}

struct NotificationRow: View {
    let item: NotificationItem
    var isUnread = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                AsyncAvatar(url: item.avatarURL, size: 36)
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
