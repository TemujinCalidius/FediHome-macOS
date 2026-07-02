import SwiftUI
import FediHomeKit

struct NotificationsView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var navigator: Navigator
    @StateObject private var model = NotificationsViewModel()

    var body: some View {
        content
            .navigationTitle(title)
            .toolbar {
                Button {
                    Task { await model.load(session: session) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(model.isLoading)
                .help("Refresh")
            }
            .task {
                if model.response == nil { await model.load(session: session) }
            }
            .onChange(of: navigator.refreshTick) { Task { await model.load(session: session) } }
    }

    private var title: String {
        model.unreadCount > 0 ? "Notifications (\(model.unreadCount))" : "Notifications"
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
            List(model.items) { item in
                NotificationRow(item: item)
            }
            .listStyle(.inset)
            .refreshable { await model.load(session: session) }
        }
    }
}

struct NotificationRow: View {
    let item: NotificationItem

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
