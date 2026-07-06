import SwiftUI

/// The macOS Settings window (⌘,).
struct SettingsView: View {
    @EnvironmentObject private var badge: BadgeModel

    @AppStorage(Prefs.notifPollKey) private var notifPoll = 30
    @AppStorage(Prefs.dmPollKey) private var dmPoll = 20
    @AppStorage(Prefs.badgePollKey) private var badgePoll = 60
    @AppStorage(Prefs.feedRepliesKey) private var feedReplies = false
    @AppStorage(Prefs.feedBoostsKey) private var feedBoosts = true
    @AppStorage(Prefs.rememberSectionKey) private var rememberSection = true
    @AppStorage(Prefs.showDockBadgeKey) private var showDockBadge = true
    @AppStorage(Prefs.notifyBannersKey) private var notifyBanners = true
    @State private var bannersDenied = false

    var body: some View {
        Form {
            Section("Check for new items every…") {
                intervalPicker("Notifications", selection: $notifPoll, options: [10, 20, 30, 60, 120, 300])
                intervalPicker("Messages", selection: $dmPoll, options: [10, 20, 30, 60, 120, 300])
                intervalPicker("Menu-bar badge", selection: $badgePoll, options: [30, 60, 120, 300, 600])
                Text("Applies while the section is open; changes take effect on the next check.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Timeline defaults") {
                Toggle("Show replies", isOn: $feedReplies)
                Toggle("Show boosts", isOn: $feedBoosts)
                Text("Used when the app opens; the Feed's filter menu still changes the current session.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("General") {
                Toggle("Remember my last section on launch", isOn: $rememberSection)
                Toggle("Show unread badge on Dock icon", isOn: $showDockBadge)
                    .onChange(of: showDockBadge) { badge.redrawDockBadge() } // apply immediately
                Toggle("Show notification banners for new activity", isOn: $notifyBanners)
                if notifyBanners && bannersDenied {
                    Label("Notifications are denied for FediHome — enable them in System Settings → Notifications.",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                } else {
                    Text("Banners appear while the app is running (the window can be closed).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize()
        .task { bannersDenied = await NotificationManager.shared.authorizationDenied() }
    }

    private func intervalPicker(_ label: String, selection: Binding<Int>, options: [Int]) -> some View {
        Picker(label, selection: selection) {
            ForEach(options, id: \.self) { seconds in
                Text(seconds < 60 ? "\(seconds) seconds"
                     : seconds == 60 ? "1 minute"
                     : "\(seconds / 60) minutes").tag(seconds)
            }
        }
    }
}
