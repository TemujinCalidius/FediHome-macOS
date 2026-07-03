import SwiftUI

@main
struct FediHomeApp: App {
    init() {
        // AsyncImage loads through URLSession.shared — give it a real cache so
        // avatars and feed media stop re-downloading on every scroll/relaunch.
        URLCache.shared = URLCache(memoryCapacity: 64 * 1024 * 1024,
                                   diskCapacity: 512 * 1024 * 1024)
    }

    @StateObject private var session = SessionStore()
    @StateObject private var imageViewer = ImageViewerModel()
    @StateObject private var navigator = Navigator()
    @StateObject private var badge = BadgeModel()

    var body: some Scene {
        // A single Window (not a WindowGroup) so opening from the menu bar reuses the
        // existing window instead of spawning duplicates.
        Window("FediHome", id: "main") {
            RootView()
                .environmentObject(session)
                .environmentObject(imageViewer)
                .environmentObject(navigator)
                .environmentObject(badge)
                .overlay { ImageViewerOverlay().environmentObject(imageViewer) }
                .frame(minWidth: 760, minHeight: 520)
                .task(id: session.phase) {
                    while !Task.isCancelled, session.phase == .connected {
                        await badge.refresh(session: session)
                        try? await Task.sleep(for: .seconds(Prefs.badgePollSeconds))
                    }
                }
        }
        .defaultSize(width: 980, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Post") { navigator.go(.compose) }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu("Go") {
                Button("Feed") { navigator.go(.feed) }.keyboardShortcut("1", modifiers: .command)
                Button("Notifications") { navigator.go(.notifications) }.keyboardShortcut("2", modifiers: .command)
                Button("New Post") { navigator.go(.compose) }.keyboardShortcut("3", modifiers: .command)
                Button("People") { navigator.go(.people) }.keyboardShortcut("4", modifiers: .command)
                Button("Messages") { navigator.go(.messages) }.keyboardShortcut("5", modifiers: .command)
                Button("My Posts") { navigator.go(.myPosts) }.keyboardShortcut("6", modifiers: .command)
                Divider()
                Button("Refresh") { navigator.refresh() }.keyboardShortcut("r", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
        }

        MenuBarExtra {
            MenuBarContent(session: session, navigator: navigator, badge: badge)
        } label: {
            if badge.total > 0 {
                Label("\(badge.total)", systemImage: "house.fill")
            } else {
                Image(systemName: "house")
            }
        }
    }
}
