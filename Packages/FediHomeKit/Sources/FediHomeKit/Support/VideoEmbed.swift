import Foundation

/// Maps a video-host **page** URL (which the feed delivers as a link/embed, not a
/// playable file) to an embeddable **player** URL for an in-app web view. Returns
/// nil for unrecognized hosts (those keep opening in the browser).
///
/// Recognizes YouTube, Vimeo, and PeerTube (heuristic — any instance's `/w/<id>` or
/// `/videos/watch/<id>` short/watch links). UI-agnostic so iOS reuses it.
public enum VideoEmbed {
    public static func embedURL(for url: URL) -> URL? {
        guard let host = url.host?.lowercased() else { return nil }
        let scheme = url.scheme ?? "https"
        let segments = pathSegments(url)

        // YouTube
        if host == "youtu.be" {
            return segments.first.flatMap(youtubeEmbed)
        }
        if host.hasSuffix("youtube.com") || host.hasSuffix("youtube-nocookie.com") {
            if url.path == "/watch", let v = queryValue(url, "v") { return youtubeEmbed(v) }
            if segments.count >= 2, ["shorts", "embed", "live", "v"].contains(segments[0]) {
                return youtubeEmbed(segments[1])
            }
            return nil
        }

        // Vimeo
        if host == "player.vimeo.com" {
            return withAutoplay(url)
        }
        if host.hasSuffix("vimeo.com") {
            if let id = segments.first, !id.isEmpty, id.allSatisfy(\.isNumber) {
                return URL(string: "https://player.vimeo.com/video/\(id)?autoplay=1")
            }
            return nil
        }

        // PeerTube (heuristic across instances): /w/<id> and /videos/watch|embed/<id>
        if segments.count == 2, segments[0] == "w" {
            return URL(string: "\(scheme)://\(host)/videos/embed/\(segments[1])?autoplay=1")
        }
        if segments.count == 3, segments[0] == "videos", segments[1] == "watch" || segments[1] == "embed" {
            return URL(string: "\(scheme)://\(host)/videos/embed/\(segments[2])?autoplay=1")
        }

        return nil
    }

    /// Whether the URL is a recognized, in-app-playable video host.
    public static func isPlayable(_ url: URL) -> Bool { embedURL(for: url) != nil }

    /// Embed metadata for **composing** a video post (`POST /api/compose` expects
    /// `embedHost` + `embedId` + `iframeSrc`). Unlike `embedURL(for:)` this is the
    /// clean iframe URL (no autoplay). Nil for unrecognized hosts.
    public struct EmbedInfo: Sendable, Equatable {
        public let embedHost: String
        public let embedId: String
        public let iframeSrc: String
    }

    public static func embedInfo(for url: URL) -> EmbedInfo? {
        guard let host = url.host?.lowercased() else { return nil }
        let scheme = url.scheme ?? "https"
        let segments = pathSegments(url)

        // YouTube
        if host == "youtu.be", let id = segments.first, !id.isEmpty {
            return EmbedInfo(embedHost: "www.youtube.com", embedId: id,
                             iframeSrc: "https://www.youtube.com/embed/\(id)")
        }
        if host.hasSuffix("youtube.com") || host.hasSuffix("youtube-nocookie.com") {
            var id: String?
            if url.path == "/watch" { id = queryValue(url, "v") }
            else if segments.count >= 2, ["shorts", "embed", "live", "v"].contains(segments[0]) { id = segments[1] }
            if let id, !id.isEmpty {
                return EmbedInfo(embedHost: "www.youtube.com", embedId: id,
                                 iframeSrc: "https://www.youtube.com/embed/\(id)")
            }
            return nil
        }

        // Vimeo
        if host.hasSuffix("vimeo.com"), host != "player.vimeo.com",
           let id = segments.first, !id.isEmpty, id.allSatisfy(\.isNumber) {
            return EmbedInfo(embedHost: "player.vimeo.com", embedId: id,
                             iframeSrc: "https://player.vimeo.com/video/\(id)")
        }

        // PeerTube (heuristic across instances)
        if segments.count == 2, segments[0] == "w" {
            return EmbedInfo(embedHost: host, embedId: segments[1],
                             iframeSrc: "\(scheme)://\(host)/videos/embed/\(segments[1])")
        }
        if segments.count == 3, segments[0] == "videos", segments[1] == "watch" || segments[1] == "embed" {
            return EmbedInfo(embedHost: host, embedId: segments[2],
                             iframeSrc: "\(scheme)://\(host)/videos/embed/\(segments[2])")
        }

        return nil
    }

    // MARK: Helpers

    private static func youtubeEmbed(_ rawID: String) -> URL? {
        let id = rawID.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else { return nil }
        return URL(string: "https://www.youtube.com/embed/\(id)?autoplay=1&playsinline=1")
    }

    private static func pathSegments(_ url: URL) -> [String] {
        url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
    }

    private static func queryValue(_ url: URL, _ name: String) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == name }?.value
    }

    private static func withAutoplay(_ url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var items = components.queryItems ?? []
        if !items.contains(where: { $0.name == "autoplay" }) {
            items.append(URLQueryItem(name: "autoplay", value: "1"))
        }
        components.queryItems = items
        return components.url
    }
}
