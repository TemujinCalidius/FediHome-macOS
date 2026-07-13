import Foundation

/// Resolves media/embed URLs from the feed, which are a mix of **absolute** remote
/// URLs (mastodon CDNs, YouTube pages) and **relative** proxied paths
/// (`/uploads/fedi/…`) that must be resolved against the instance base URL.
public enum MediaURL {
    /// Absolute (http/https) → used as-is; anything else → resolved against `base`.
    public static func resolve(_ raw: String, relativeTo base: URL) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return url
        }
        return URL(string: trimmed, relativeTo: base)?.absoluteURL
    }

    static let videoFileExtensions: Set<String> = ["mp4", "webm", "mov", "m4v", "ogv", "ogg"]

    /// A `"video"` item is inline-playable when it's a direct media file (by extension)
    /// or lives on the instance host (a proxied `/uploads/fedi/…` file). Streaming *page*
    /// URLs (youtube.com/watch, vimeo.com/…) are not — those link out instead.
    public static func isDirectVideoFile(_ url: URL, instanceHost: String?) -> Bool {
        if videoFileExtensions.contains(url.pathExtension.lowercased()) { return true }
        if let instanceHost, let host = url.host, host == instanceHost { return true }
        return false
    }
}
