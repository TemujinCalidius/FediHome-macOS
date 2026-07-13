import SwiftUI
import AppKit

@main
struct FediHomeApp: App {
    init() {
        // AsyncImage loads through URLSession.shared — give it a real cache so
        // avatars and feed media stop re-downloading on every scroll/relaunch.
        URLCache.shared = URLCache(memoryCapacity: 64 * 1024 * 1024,
                                   diskCapacity: 512 * 1024 * 1024)
        // Install the notification delegate at launch, so a banner click that
        // *launches* the app still routes correctly.
        MainActor.assumeIsolated { NotificationManager.shared.setupDelegate() }
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
                // NOTE: no polling here — the badge/banner poll lives on the menu-bar
                // label below, which (unlike this window) survives the window closing.
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
                .environmentObject(badge) // the Dock-badge toggle applies immediately
        }

        MenuBarExtra {
            MenuBarContent(session: session, navigator: navigator, badge: badge)
        } label: {
            MenuBarPollingLabel(session: session, navigator: navigator, badge: badge)
        }
    }
}

/// The status-bar label doubles as the app's polling engine: unlike the main window's
/// content, it stays alive for the app's entire lifetime, so badges and banners keep
/// working after the window is closed (the advertised menu-bar-app use case).
private struct MenuBarPollingLabel: View {
    @ObservedObject var session: SessionStore
    let navigator: Navigator
    @ObservedObject var badge: BadgeModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            if badge.total > 0 {
                Label("\(badge.total)", systemImage: "house.fill")
            } else {
                Image(systemName: "house")
            }
        }
        .task(id: session.phase) {
            NotificationManager.shared.attach(navigator: navigator) {
                openWindow(id: "main") // reopen if closed — banner clicks must work
                NSApp.activate(ignoringOtherApps: true)
            }
            guard session.phase == .connected else {
                badge.reset() // disconnect visibly clears Dock + menu-bar counts
                return
            }
            while !Task.isCancelled, session.phase == .connected {
                await badge.refresh(session: session)
                try? await Task.sleep(for: .seconds(Prefs.badgePollSeconds))
            }
        }
    }
}
