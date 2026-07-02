import Foundation
import FediHomeKit

@MainActor
final class ComposeViewModel: ObservableObject {
    struct Attachment: Identifiable, Equatable {
        let id = UUID()
        let previewData: Data
        let url: String
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
    @Published private(set) var attachments: [Attachment] = []
    @Published private(set) var isUploading = false
    @Published private(set) var isPosting = false
    @Published var errorMessage: String?
    @Published var successURL: URL?
    /// Set when the post was scheduled rather than published.
    @Published var scheduledConfirmation: Date?

    /// A title routes the post to Articles; without one it's a note (→ the instance's Journal).
    var isArticle: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var characterCount: Int { content.count }
    /// Advisory: long no-title posts read better as articles (and Bluesky truncates at 300).
    var suggestsArticle: Bool { characterCount > 300 && !isArticle }
    var descriptionCount: Int { postDescription.count }
    /// Advisory cap for the article description (microblog-length).
    var descriptionOverLimit: Bool { descriptionCount > 300 }

    var canPost: Bool {
        let hasBody = !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let scheduleOK = !isScheduling || scheduledDate > Date()
        return (hasBody || !attachments.isEmpty) && scheduleOK && !isPosting && !isUploading
    }

    func addPhotos(urls: [URL], session: SessionStore) async {
        guard let client = session.client else { return }
        isUploading = true
        defer { isUploading = false }
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { continue }
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

    func post(session: SessionStore) async {
        guard let client = session.client, canPost else { return }
        isPosting = true
        errorMessage = nil
        defer { isPosting = false }
        do {
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
            } else {
                let result = try await client.composePost(
                    content: content,
                    title: isArticle ? title : nil,
                    description: isArticle ? postDescription : nil,
                    photos: attachments.map { ComposePhoto(url: $0.url) },
                    crosspostBluesky: crosspostBluesky,
                    crosspostThreads: crosspostThreads,
                    scheduledFor: isScheduling ? scheduledDate : nil
                )
                successURL = result.post.webURL ?? session.resolvedBaseURL
                scheduledConfirmation = result.isScheduled ? (result.post.scheduledFor ?? scheduledDate) : nil
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
