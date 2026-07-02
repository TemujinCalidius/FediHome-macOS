import Foundation

/// Builds the JSON body for `POST /api/compose` (FediHome's rich compose endpoint,
/// `create` scope). Mirrors the server's typed request: a `title` makes the post an
/// article, `description` becomes the article excerpt/AP summary, media arrays carry
/// already-uploaded/derived metadata, gallery flags opt content into the instance's
/// Photography/Videos/Audio sections, and a **future** `scheduledFor` schedules
/// instead of publishing. Nil/empty fields are omitted.
public enum ComposeBody {
    public static func build(
        content: String,
        title: String? = nil,
        description: String? = nil,
        photos: [ComposePhoto] = [],
        videos: [ComposeVideo] = [],
        audios: [ComposeAudio] = [],
        addToPhotography: Bool = false,
        photoCategory: String? = nil,
        addToVideos: Bool = false,
        videoCategory: String? = nil,
        addToAudio: Bool = false,
        audioCategory: String? = nil,
        crosspostBluesky: Bool = false,
        crosspostThreads: Bool = false,
        scheduledFor: Date? = nil
    ) -> [String: Any] {
        var body: [String: Any] = [:]
        body["content"] = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if let title = trimmedNonEmpty(title) { body["title"] = title }
        if let description = trimmedNonEmpty(description) { body["description"] = description }

        if !photos.isEmpty {
            body["photos"] = photos.map { ["url": $0.url, "alt": $0.alt] }
        }
        if !videos.isEmpty {
            body["videos"] = videos.map { video -> [String: Any] in
                var dict: [String: Any] = [
                    "url": video.url,
                    "title": video.title,
                    "embedHost": video.embedHost,
                    "embedId": video.embedId,
                    "iframeSrc": video.iframeSrc,
                ]
                if let thumb = video.thumbnailUrl { dict["thumbnailUrl"] = thumb }
                if let duration = video.duration { dict["duration"] = duration }
                return dict
            }
        }
        if !audios.isEmpty {
            body["audios"] = audios.map { audio -> [String: Any] in
                var dict: [String: Any] = ["url": audio.url, "title": audio.title]
                if let duration = audio.durationSec { dict["durationSec"] = duration }
                if let size = audio.fileSize { dict["fileSize"] = size }
                if let cover = audio.coverImage { dict["coverImage"] = cover }
                return dict
            }
        }

        if addToPhotography {
            body["addToPhotography"] = true
            if let category = trimmedNonEmpty(photoCategory) { body["photoCategory"] = category }
        }
        if addToVideos {
            body["addToVideos"] = true
            if let category = trimmedNonEmpty(videoCategory) { body["videoCategory"] = category }
        }
        if addToAudio {
            body["addToAudio"] = true
            if let category = trimmedNonEmpty(audioCategory) { body["audioCategory"] = category }
        }

        if crosspostBluesky { body["crosspostBluesky"] = true }
        if crosspostThreads { body["crosspostThreads"] = true }

        if let scheduledFor {
            // Sendable ISO-8601 style (Swift 6): "2026-07-15T14:30:00Z"
            body["scheduledFor"] = scheduledFor.formatted(.iso8601)
        }
        return body
    }

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
