import Foundation

/// A gallery category on the instance — a `{slug, label}` pair from the compose config
/// (`GET /api/micropub?q=config`). Show `label`; submit `slug` (what the server stores).
public struct MediaCategory: Codable, Sendable, Equatable, Identifiable {
    public let slug: String
    public let label: String
    public var id: String { slug }
}

/// `GET /api/micropub?q=config` — the instance's Micropub config. We only model
/// `mediaCategories` (the compose gallery pickers); other keys (post-types, media
/// endpoint, …) are ignored.
public struct ServerConfig: Codable, Sendable, Equatable {
    public struct MediaCategories: Codable, Sendable, Equatable {
        public let photos: [MediaCategory]
        public let videos: [MediaCategory]
        public let audio: [MediaCategory]
        public static let empty = MediaCategories(photos: [], videos: [], audio: [])
    }

    /// Absent on instances older than the build that shipped it (FediHome#284) — decodes
    /// as `nil`, in which case the app falls back to free-text category entry.
    public let mediaCategories: MediaCategories?
}
