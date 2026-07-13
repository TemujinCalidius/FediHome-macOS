import Foundation

/// Response from `POST /api/compose`. Published posts return `{success, post}`;
/// scheduled posts add `scheduled: true` (HTTP 201) and a `scheduledFor` on the post;
/// edits add `edited: true`.
public struct ComposeResult: Codable, Sendable, Equatable {
    public let success: Bool
    public let scheduled: Bool?
    public let edited: Bool?
    public let post: ComposePost

    public var isScheduled: Bool { scheduled == true }
}

public struct ComposePost: Codable, Sendable, Equatable {
    public let id: String
    public let slug: String
    public let url: String
    public let scheduledFor: Date?

    public var webURL: URL? { URL(string: url) }

    public init(id: String, slug: String, url: String, scheduledFor: Date? = nil) {
        self.id = id
        self.slug = slug
        self.url = url
        self.scheduledFor = scheduledFor
    }
}

// MARK: - Compose attachments (request side)

/// A photo already uploaded via `/api/media`, with its caption/alt text.
public struct ComposePhoto: Sendable, Equatable {
    public let url: String
    public let alt: String

    public init(url: String, alt: String = "") {
        self.url = url
        self.alt = alt
    }
}

/// A video embed (canonical PeerTube/YouTube/Vimeo page URL + derived embed metadata).
public struct ComposeVideo: Sendable, Equatable {
    public let url: String
    public let title: String
    public let embedHost: String
    public let embedId: String
    public let iframeSrc: String
    public let thumbnailUrl: String?
    public let duration: Int?

    public init(url: String, title: String, embedHost: String, embedId: String,
                iframeSrc: String, thumbnailUrl: String? = nil, duration: Int? = nil) {
        self.url = url
        self.title = title
        self.embedHost = embedHost
        self.embedId = embedId
        self.iframeSrc = iframeSrc
        self.thumbnailUrl = thumbnailUrl
        self.duration = duration
    }
}

/// An audio file already uploaded via `/api/media` (which supplies duration/size).
public struct ComposeAudio: Sendable, Equatable {
    public let url: String
    public let title: String
    public let durationSec: Int?
    public let fileSize: Int?
    public let coverImage: String?

    public init(url: String, title: String, durationSec: Int? = nil,
                fileSize: Int? = nil, coverImage: String? = nil) {
        self.url = url
        self.title = title
        self.durationSec = durationSec
        self.fileSize = fileSize
        self.coverImage = coverImage
    }
}
