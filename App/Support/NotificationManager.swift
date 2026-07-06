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
    private var authorizationRequested = false

    private var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    func attach(navigator: Navigator) {
        self.navigator = navigator
        guard isAvailable else { return }
        UNUserNotificationCenter.current().delegate = self
    }

    /// Posts a banner (requesting permission on first use). `section` is where a
    /// click takes the user.
    func post(title: String, body: String, section: AppSection) {
        guard isAvailable else { return }
        Task {
            await requestAuthorizationIfNeeded()
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

    private func requestAuthorizationIfNeeded() async {
        guard !authorizationRequested else { return }
        authorizationRequested = true
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: UNUserNotificationCenterDelegate

    /// Show banners even while the app is frontmost.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// Banner clicked → bring the app forward and jump to the relevant section.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let raw = response.notification.request.content.userInfo["section"] as? String
        await MainActor.run {
            NSApp.activate(ignoringOtherApps: true)
            if let raw, let section = AppSection(rawValue: raw) {
                navigator?.go(section)
            }
        }
    }
}
