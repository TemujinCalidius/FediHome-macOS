import SwiftUI
import FediHomeKit

struct MainView: View {
    @EnvironmentObject private var session: SessionStore

    enum Section: Hashable { case feed, notifications, compose }
    @State private var selection: Section? = .feed

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Feed", systemImage: "house").tag(Section.feed)
                Label("Notifications", systemImage: "bell").tag(Section.notifications)
                Label("New Post", systemImage: "square.and.pencil").tag(Section.compose)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 280)
            .safeAreaInset(edge: .bottom) { accountFooter }
        } detail: {
            switch selection ?? .feed {
            case .feed: FeedView()
            case .notifications: NotificationsView()
            case .compose: ComposeView()
            }
        }
    }

    private var accountFooter: some View {
        HStack(spacing: 10) {
            AsyncAvatar(url: session.account?.avatarURL, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.account?.displayName ?? "—")
                    .font(.callout).bold().lineLimit(1)
                Text(session.account?.fediAddress ?? session.account?.handle ?? "")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Menu {
                Button("Disconnect", role: .destructive) { session.disconnect() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
}
