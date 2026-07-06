import Foundation

/// App preferences (Settings window ⌘,). Readers use these accessors — with explicit
/// fallbacks — rather than `register(defaults:)`, so defaults hold no matter when a
/// reader runs (e.g. `Navigator` is constructed before any registration could happen).
enum Prefs {
    static let notifPollKey = "notifPollSeconds"
    static let dmPollKey = "dmPollSeconds"
    static let badgePollKey = "badgePollSeconds"
    static let feedRepliesKey = "feedDefaultReplies"
    static let feedBoostsKey = "feedDefaultBoosts"
    static let rememberSectionKey = "rememberSection"
    static let showDockBadgeKey = "showDockBadge"

    /// Poll intervals are clamped so a corrupted default can't hammer the instance.
    static var notifPollSeconds: Int { max(10, intOr(30, notifPollKey)) }
    static var dmPollSeconds: Int { max(10, intOr(20, dmPollKey)) }
    static var badgePollSeconds: Int { max(30, intOr(60, badgePollKey)) }

    static var feedDefaultReplies: Bool { boolOr(false, feedRepliesKey) }
    static var feedDefaultBoosts: Bool { boolOr(true, feedBoostsKey) }
    static var rememberSection: Bool { boolOr(true, rememberSectionKey) }
    static var showDockBadge: Bool { boolOr(true, showDockBadgeKey) }

    private static func intOr(_ fallback: Int, _ key: String) -> Int {
        UserDefaults.standard.object(forKey: key) as? Int ?? fallback
    }

    private static func boolOr(_ fallback: Bool, _ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? fallback
    }
}
