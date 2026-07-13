import AppKit
import UserNotifications

/// Posts native macOS notification banners for new fediverse activity and DMs, and
/// routes banner clicks to the right section. App-target only (not FediHomeKit).
///
/// Safe in unbundled contexts (swift test never touches `UNUserNotificationCenter`;
/// we also guard on a bundle identifier being present).
@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    /// Where banner clicks navigate; attached once the UI exists.
    private weak var navigator: Navigator?
    /// Reopens the main window (a banner click must work with the window closed).
    private var openMainWindow: (() -> Void)?
    /// Single in-flight/cached authorization check — concurrent posts await the same one.
    private var authTask: Task<Bool, Never>?

    private var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    /// Call at app launch (before any banner click can arrive — including clicks that
    /// launch the app) so the delegate is installed early.
    func setupDelegate() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().delegate = self
    }

    func attach(navigator: Navigator, openWindow: @escaping () -> Void) {
        self.navigator = navigator
        self.openMainWindow = openWindow
        setupDelegate()
    }

    /// Posts a banner (resolving permission first). `section` is where a click takes
    /// the user. Silently a no-op when permission is denied.
    func post(title: String, body: String, section: AppSection) {
        guard isAvailable else { return }
        Task {
            guard await ensureAuthorized() else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.userInfo = ["section": section.rawValue]
            let request = UNNotificationRequest(identifier: UUID().uuidString,
                                                content: content, trigger: nil)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    /// Whether the user has denied notifications in System Settings (for a hint in ⌘,).
    func authorizationDenied() async -> Bool {
        guard isAvailable else { return false }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .denied
    }

    private func ensureAuthorized() async -> Bool {
        if let authTask { return await authTask.value }
        let task = Task { () -> Bool in
            let center = UNUserNotificationCenter.current()
            switch await center.notificationSettings().authorizationStatus {
            case .authorized, .provisional:
                return true
            case .denied:
                return false
            default:
                return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            }
        }
        authTask = task
        return await task.value
    }

    // MARK: UNUserNotificationCenterDelegate

    /// Show banners even while the app is frontmost.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// Banner clicked → reopen/bring forward the window and jump to the section.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let raw = response.notification.request.content.userInfo["section"] as? String
        await MainActor.run {
            if let openMainWindow {
                openMainWindow() // reopens the Window scene if closed, then activates
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }
            if let raw, let section = AppSection(rawValue: raw) {
                navigator?.go(section)
            }
        }
    }
}
