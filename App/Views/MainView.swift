import SwiftUI
import FediHomeKit

struct MainView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var navigator: Navigator
    @State private var showingMe = false

    var body: some View {
        NavigationSplitView {
            List(selection: sectionSelection) {
                Label("Feed", systemImage: "house").tag(AppSection.feed)
                Label("Notifications", systemImage: "bell").tag(AppSection.notifications)
                Label("New Post", systemImage: "square.and.pencil").tag(AppSection.compose)
                Label("People", systemImage: "person.2").tag(AppSection.people)
                Label("Messages", systemImage: "bubble.left.and.bubble.right").tag(AppSection.messages)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 280)
            .safeAreaInset(edge: .bottom) { accountFooter }
        } detail: {
            switch navigator.section {
            case .feed: FeedView()
            case .notifications: NotificationsView()
            case .compose: ComposeView()
            case .people: PeopleView()
            case .messages: DirectMessagesView()
            }
        }
    }

    private var sectionSelection: Binding<AppSection?> {
        Binding(get: { navigator.section }, set: { navigator.section = $0 ?? .feed })
    }

    private var accountFooter: some View {
        HStack(spacing: 10) {
            Button { showingMe = true } label: {
                HStack(spacing: 10) {
                    AsyncAvatar(url: session.account?.avatarURL, size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(session.account?.displayName ?? "—")
                            .font(.callout).bold().lineLimit(1)
                        Text(session.account?.fediAddress ?? session.account?.handle ?? "")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Your profile")
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
        .sheet(isPresented: $showingMe) {
            if let account = session.account {
                MeView(account: account, baseURL: session.resolvedBaseURL)
            }
        }
    }
}
