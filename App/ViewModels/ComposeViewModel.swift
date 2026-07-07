import Foundation
import FediHomeKit

@MainActor
final class ComposeViewModel: ObservableObject {
    struct Attachment: Identifiable, Equatable {
        let id = UUID()
        let previewData: Data
        let url: String
        /// Caption / alt text, editable in the photo strip.
        var alt: String = ""
    }

    struct AudioAttachment: Identifiable, Equatable {
        let id = UUID()
        let url: String
        var title: String
        let durationSec: Int?
        let fileSize: Int?
        let filename: String
    }

    @Published var content = ""
    @Published var title = ""
    /// Article description → the post's excerpt / AP summary (shown when a title is set).
    @Published var postDescription = ""
    @Published var isDraft = false
    /// Schedule instead of publishing now (server-side publish at `scheduledDate`).
    @Published var isScheduling = false
    @Published var scheduledDate = Date().addingTimeInterval(3600)
    @Published var crosspostBluesky = true
    @Published var crosspostThreads = true
    @Published var attachments: [Attachment] = [] // settable: captions bind per-thumbnail
    @Published var addPhotosToGallery = false
    @Published var photoCategory = ""

    // Video embed (URL-based — the file stays on its host)
    @Published var includeVideo = false
    @Published var videoURLString = ""
    @Published var videoTitle = ""
    @Published var addVideoToGallery = false
    @Published var videoCategory = ""

    // Audio uploads
    @Published var audioAttachments: [AudioAttachment] = []
    @Published var addAudioToGallery = false
    @Published var audioCategory = ""

    @Published private(set) var isUploading = false
    @Published private(set) var isPosting = false
    @Published var errorMessage: String?
    @Published var successURL: URL?
    /// Set when the post was scheduled rather than published.
    @Published var scheduledConfirmation: Date?
    /// True when the last success was a draft save (not a publish).
    @Published var savedAsDraft = false
    /// True when the last success was an edit (not a new post).
    @Published var savedEdit = false

    // Edit mode (My Posts → Edit): text/title/description only — media stays
    // untouched (q=source carries no media, and /api/compose edits are opt-in).
    @Published private(set) var editingPostId: String?
    @Published private(set) var editingDisplayTitle = ""
    /// The post being edited started as an article — clearing its title mid-edit is
    /// blocked (the server would keep it an article but null the title and excerpt).
    @Published private(set) var editingWasArticle = false
    var isEditing: Bool { editingPostId != nil }

    /// True when the composer holds an unsaved NEW post (not an edit) — used to warn
    /// before an Edit… would replace it.
    var hasUnsentInput: Bool {
        guard !isEditing else { return false }
        return !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !attachments.isEmpty || !audioAttachments.isEmpty || includeVideo
    }

    /// A title routes the post to Articles; without one it's a note (→ the instance's Journal).
    var isArticle: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var characterCount: Int { content.count }
    /// Advisory: long no-title posts read better as articles (and Bluesky truncates at 300).
    var suggestsArticle: Bool { characterCount > 300 && !isArticle }
    var descriptionCount: Int { postDescription.count }
    /// Advisory cap for the article description (microblog-length).
    var descriptionOverLimit: Bool { descriptionCount > 300 }

    /// Derived embed metadata for the video URL; nil when empty or unrecognized.
    var videoEmbedInfo: VideoEmbed.EmbedInfo? {
        guard let url = URL(string: videoURLString.trimmingCharacters(in: .whitespaces)) else { return nil }
        return VideoEmbed.embedInfo(for: url)
    }
    /// True when a video URL was entered but isn't a recognized host.
    var videoURLInvalid: Bool {
        includeVideo && !videoURLString.trimmingCharacters(in: .whitespaces).isEmpty && videoEmbedInfo == nil
    }

    /// Why posting is blocked (nil = good to go). Mirrors the server's rules:
    /// `/api/compose` requires non-empty content; Micropub drafts accept content OR photos.
    var blockedReason: String? {
        let hasBody = !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if isEditing {
            if !hasBody { return "Posts need some text." }
            if editingWasArticle && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Keep a title — this is an article."
            }
        } else if isDraft {
            if !hasBody && attachments.isEmpty { return "Drafts need text (or a photo)." }
        } else {
            if !hasBody { return "Posts need some text." }
            if includeVideo && videoEmbedInfo == nil { return "Finish or remove the video URL." }
            if isScheduling && scheduledDate <= Date() { return "Pick a schedule time in the future." }
        }
        return nil
    }

    var canPost: Bool {
        blockedReason == nil && !isPosting && !isUploading
    }

    func addPhotos(urls: [URL], session: SessionStore) async {
        guard let client = session.client else { return }
        isUploading = true
        defer { isUploading = false }
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                errorMessage = "Couldn't read \(url.lastPathComponent)."
                continue
            }
            do {
                let upload = try await client.uploadMedia(data, filename: url.lastPathComponent,
                                                          mimeType: Self.mimeType(for: url))
                attachments.append(Attachment(previewData: data, url: upload.url))
            } catch APIError.unauthorized {
                session.reportUnauthorized(); return
            } catch {
                errorMessage = Self.message(for: error)
            }
        }
    }

    func removeAttachment(_ attachment: Attachment) {
        attachments.removeAll { $0.id == attachment.id }
    }

    func addAudio(urls: [URL], session: SessionStore) async {
        guard let client = session.client else { return }
        isUploading = true
        defer { isUploading = false }
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                errorMessage = "Couldn't read \(url.lastPathComponent)."
                continue
            }
            do {
                let upload = try await client.uploadMedia(data, filename: url.lastPathComponent,
                                                          mimeType: "audio/mpeg")
                let title = url.deletingPathExtension().lastPathComponent
                audioAttachments.append(AudioAttachment(url: upload.url, title: title,
                                                        durationSec: upload.durationSec,
                                                        fileSize: upload.fileSize,
                                                        filename: url.lastPathComponent))
            } catch APIError.unauthorized {
                session.reportUnauthorized(); return
            } catch {
                errorMessage = Self.message(for: error)
            }
        }
    }

    func removeAudio(_ audio: AudioAttachment) {
        audioAttachments.removeAll { $0.id == audio.id }
    }

    /// Loads a post's source into the composer for editing. Returns false (with an
    /// error set) when the post can't be edited.
    func beginEditing(_ post: OwnPost, session: SessionStore) async -> Bool {
        guard let client = session.client else { return false }
        guard let serverId = post.serverId else {
            errorMessage = "This post can't be edited — your instance needs the latest FediHome."
            return false
        }
        let webURL = post.webURL(relativeTo: session.resolvedBaseURL)?.absoluteString ?? post.url
        do {
            let source = try await client.postSource(url: webURL)
            reset()
            startNew()
            content = source.content
            title = source.title ?? ""
            postDescription = source.summary ?? ""
            editingPostId = serverId
            editingDisplayTitle = post.displayTitle
            editingWasArticle = !(source.title ?? "").isEmpty
            return true
        } catch APIError.unauthorized {
            session.reportUnauthorized(); return false
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
    }

    func cancelEditing() {
        reset()
        startNew()
    }

    func post(session: SessionStore) async {
        guard let client = session.client, canPost else { return }
        isPosting = true
        errorMessage = nil
        defer { isPosting = false }
        do {
            if let editingPostId {
                let result = try await client.composePost(
                    content: content,
                    title: isArticle ? title : nil,
                    description: isArticle ? postDescription : nil,
                    editingPostId: editingPostId
                    // media omitted on purpose → the server keeps it untouched
                )
                successURL = result.post.webURL ?? session.resolvedBaseURL
                scheduledConfirmation = nil
                savedAsDraft = false
                savedEdit = true
                reset()
                return
            }
            if isDraft {
                // /api/compose has no draft flag — drafts go via Micropub (with summary).
                let url = try await client.createPost(
                    content: content,
                    title: isArticle ? title : nil,
                    summary: isArticle ? postDescription : nil,
                    photoURLs: attachments.map(\.url),
                    draft: true
                )
                successURL = url ?? session.resolvedBaseURL
                scheduledConfirmation = nil
                savedAsDraft = true
                savedEdit = false
            } else {
                var videos: [ComposeVideo] = []
                if includeVideo, let info = videoEmbedInfo {
                    videos.append(ComposeVideo(
                        url: videoURLString.trimmingCharacters(in: .whitespaces),
                        title: videoTitle.trimmingCharacters(in: .whitespaces),
                        embedHost: info.embedHost, embedId: info.embedId, iframeSrc: info.iframeSrc
                    ))
                }
                let result = try await client.composePost(
                    content: content,
                    title: isArticle ? title : nil,
                    description: isArticle ? postDescription : nil,
                    photos: attachments.map { ComposePhoto(url: $0.url, alt: $0.alt) },
                    videos: videos,
                    audios: audioAttachments.map {
                        ComposeAudio(url: $0.url, title: $0.title,
                                     durationSec: $0.durationSec, fileSize: $0.fileSize)
                    },
                    addToPhotography: addPhotosToGallery && !attachments.isEmpty,
                    photoCategory: photoCategory,
                    addToVideos: addVideoToGallery && !videos.isEmpty,
                    videoCategory: videoCategory,
                    addToAudio: addAudioToGallery && !audioAttachments.isEmpty,
                    audioCategory: audioCategory,
                    crosspostBluesky: crosspostBluesky,
                    crosspostThreads: crosspostThreads,
                    scheduledFor: isScheduling ? scheduledDate : nil
                )
                successURL = result.post.webURL ?? session.resolvedBaseURL
                scheduledConfirmation = result.isScheduled ? (result.post.scheduledFor ?? scheduledDate) : nil
                savedAsDraft = false
                savedEdit = false
            }
            reset()
        } catch APIError.unauthorized {
            session.reportUnauthorized()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func startNew() {
        successURL = nil
        scheduledConfirmation = nil
        savedAsDraft = false
        savedEdit = false
        errorMessage = nil
    }

    private func reset() {
        content = ""
        title = ""
        postDescription = ""
        isDraft = false
        isScheduling = false
        scheduledDate = Date().addingTimeInterval(3600)
        attachments = []
        addPhotosToGallery = false
        photoCategory = ""
        includeVideo = false
        videoURLString = ""
        videoTitle = ""
        addVideoToGallery = false
        videoCategory = ""
        audioAttachments = []
        addAudioToGallery = false
        audioCategory = ""
        editingPostId = nil
        editingDisplayTitle = ""
        editingWasArticle = false
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "webp": return "image/webp"
        case "gif": return "image/gif"
        case "heic": return "image/heic"
        default: return "application/octet-stream"
        }
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
