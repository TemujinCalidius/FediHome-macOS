import SwiftUI
import AppKit

/// The menu shown from the status-bar item.
struct MenuBarContent: View {
    @ObservedObject var session: SessionStore
    @ObservedObject var navigator: Navigator
    @ObservedObject var badge: BadgeModel

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if session.phase == .connected {
            Text(session.account?.fediAddress ?? session.account?.handle ?? "FediHome")
            Divider()
            Button("Notifications (\(badge.notificationCount))") { open(.notifications) }
            Button("Messages — \(badge.unreadMessages) unread") { open(.messages) }
            Divider()
            Button("New Post") { open(.compose) }
            Button("Open FediHome") { openMain() }
            Button("Refresh") { Task { await badge.refresh(session: session) } }
            Divider()
            Button("Disconnect") { session.disconnect() }
        } else {
            Button("Open FediHome") { openMain() }
        }
    }

    private func open(_ section: AppSection) {
        navigator.go(section)
        openMain()
    }

    private func openMain() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
