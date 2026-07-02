import Foundation

/// The authenticated client for a single FediHome instance. Holds the base URL +
/// bearer token and exposes typed read and write calls for the app API. An `actor`
/// so it's safe to share across the app; UI-agnostic so iOS reuses it verbatim.
public actor FediHomeClient {
    public let baseURL: URL
    private let token: String
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(baseURL: URL, token: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
        self.decoder = .fediHome
    }

    // MARK: Read API

    /// `GET /api/account` — the connected identity. Also the canonical
    /// "is this token still valid?" probe (it 401s cleanly).
    public func account() async throws -> Account {
        try await get("/api/account")
    }

    /// `GET /api/feed` — one page of the private timeline.
    /// - Parameters:
    ///   - cursor: ISO-8601 `publishedAt` from a previous page's `nextCursor`.
    ///   - replies: include reply posts (server default: false).
    ///   - boosts: include boosted posts (server default: false; we default true for a fuller timeline).
    public func feed(cursor: String? = nil, replies: Bool = false, boosts: Bool = true) async throws -> FeedPage {
        var query: [URLQueryItem] = []
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        if replies { query.append(URLQueryItem(name: "replies", value: "1")) }
        if boosts { query.append(URLQueryItem(name: "boosts", value: "1")) }
        return try await get("/api/feed", query: query)
    }

    /// `GET /api/notifications` — the bell. Note: returns an empty payload with
    /// HTTP 200 (not 401) for an invalid token, so don't use it to detect auth.
    public func notifications() async throws -> NotificationsResponse {
        try await get("/api/notifications")
    }

    /// `POST /api/notifications` — mark all notifications read (`interact` scope).
    public func markAllNotificationsRead() async throws {
        try await postVoid("/api/notifications", body: [:])
    }

    /// `POST /api/fedi-post-counts` — lazily fetch a post's like/boost/reply counts
    /// (`read` scope). `postId` is the local `FediPost.id`, not the apId.
    public func postCounts(postId: String) async throws -> PostCounts {
        try await postJSON("/api/fedi-post-counts", body: ["postId": postId])
    }

    /// `GET /api/conversation?postId=` — the full thread for a post (`read` scope).
    public func conversation(postId: String) async throws -> ConversationThread {
        try await get("/api/conversation", query: [URLQueryItem(name: "postId", value: postId)])
    }

    // MARK: Write API — interactions (`interact` scope) via `POST /api/admin`

    public func like(postApId: String, targetInbox: String? = nil) async throws {
        try await admin(action: "like", ["postApId": postApId, "targetInbox": targetInbox])
    }

    public func unlike(postApId: String, targetInbox: String? = nil) async throws {
        try await admin(action: "unlike", ["postApId": postApId, "targetInbox": targetInbox])
    }

    public func boost(postApId: String, targetInbox: String? = nil) async throws {
        try await admin(action: "boost", ["postApId": postApId, "targetInbox": targetInbox])
    }

    public func unboost(postApId: String, targetInbox: String? = nil) async throws {
        try await admin(action: "unboost", ["postApId": postApId, "targetInbox": targetInbox])
    }

    /// `reply` action. `targetInbox`/`actorUri` help the server address the recipient;
    /// `mentionHandle` lets it de-duplicate a leading @mention.
    public func reply(
        content: String,
        inReplyTo: String,
        targetInbox: String? = nil,
        actorUri: String? = nil,
        mentionHandle: String? = nil,
        crosspostBluesky: Bool = false
    ) async throws {
        try await admin(action: "reply", [
            "content": content,
            "inReplyTo": inReplyTo,
            "targetInbox": targetInbox,
            "actorUri": actorUri,
            "mentionHandle": mentionHandle,
            "crosspostBluesky": crosspostBluesky ? true : nil,
        ])
    }

    /// Dispatches one `POST /api/admin` action, dropping nil fields.
    private func admin(action: String, _ fields: [String: Any?]) async throws {
        var body: [String: Any] = ["action": action]
        for (key, value) in fields { if let value { body[key] = value } }
        try await postVoid("/api/admin", body: body)
    }

    // MARK: Social graph & people

    /// `GET /api/graph` — followers/following (`read` scope).
    public func graph() async throws -> SocialGraph {
        try await get("/api/graph")
    }

    /// `GET /api/profile?actor=` — a known actor's full profile (`read` scope).
    public func profile(actor: String) async throws -> Profile {
        try await get("/api/profile", query: [URLQueryItem(name: "actor", value: actor)])
    }

    /// `GET /api/profile?handle=@user@domain` — resolve/discover by handle (`read`
    /// scope). Unknown actors return a lightweight card (`partial: true`).
    public func profile(handle: String) async throws -> Profile {
        try await get("/api/profile", query: [URLQueryItem(name: "handle", value: handle)])
    }

    /// Follow a fediverse actor by `@user@domain` (`interact` scope; server resolves via WebFinger).
    public func follow(handle: String) async throws {
        try await admin(action: "follow", ["handle": handle])
    }

    /// Unfollow by actor URI (`interact` scope).
    public func unfollow(actorUri: String) async throws {
        try await admin(action: "unfollow_by_uri", ["actorUri": actorUri])
    }

    /// Block an actor (`manage` scope) — unfollows and deletes their posts/interactions.
    public func block(actorUri: String) async throws {
        try await admin(action: "block", ["actorUri": actorUri])
    }

    /// Unblock an actor (`manage` scope) — removes the block record and federates Undo(Block).
    public func unblock(actorUri: String) async throws {
        try await admin(action: "unblock", ["actorUri": actorUri])
    }

    // MARK: Direct messages (`dm` scope)

    /// `GET /api/dms` — all direct messages + per-conversation read state.
    public func directMessages() async throws -> DirectMessagesResponse {
        try await get("/api/dms")
    }

    /// Send a fediverse DM. `reply` uses `dm_reply` (into an existing conversation, by
    /// `recipientUri`); otherwise `dm_new_fedi` (by `recipientHandle`).
    public func sendDM(content: String, recipientUri: String? = nil,
                       recipientHandle: String? = nil, reply: Bool = false) async throws {
        try await admin(action: reply ? "dm_reply" : "dm_new_fedi", [
            "content": content,
            "recipientUri": recipientUri,
            "recipientHandle": recipientHandle,
        ])
    }

    public func markDMRead(conversationKey: String) async throws {
        try await admin(action: "mark_dm_read", ["conversationKey": conversationKey])
    }

    public func markAllDMsRead() async throws {
        try await admin(action: "mark_all_dms_read", [:])
    }

    // MARK: Own content (`read` scope) — the "My Posts" manager

    /// `GET /api/posts` — the owner's own posts, including drafts and scheduled.
    /// - Parameters:
    ///   - status: `published` | `draft` | `scheduled` (nil = all)
    ///   - type: `note` | `article` | `journal` | `photo` | `video` | `audio` (nil = all)
    public func ownPosts(cursor: String? = nil, status: String? = nil,
                         type: String? = nil, limit: Int? = nil) async throws -> OwnPostsPage {
        var query: [URLQueryItem] = []
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let status { query.append(URLQueryItem(name: "status", value: status)) }
        if let type { query.append(URLQueryItem(name: "type", value: type)) }
        if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }
        return try await get("/api/posts", query: query)
    }

    /// Micropub `action=delete` (`delete` scope) — removes a post (a scheduled post's
    /// delete doubles as "cancel"), federates the removal. 204 on success.
    public func deletePost(url: String) async throws {
        try await postVoid("/api/micropub", body: ["action": "delete", "url": url])
    }

    // MARK: Compose (`create` / `media` scopes)

    /// `POST /api/media` — upload an image or audio file (multipart `file` field).
    public func uploadMedia(_ data: Data, filename: String, mimeType: String) async throws -> MediaUpload {
        let request = try makeMultipart(path: "/api/media", fieldName: "file",
                                        filename: filename, mimeType: mimeType, fileData: data)
        return try decode(from: try await sendFull(request).0)
    }

    /// `POST /api/micropub` — create a note (no title → the instance's Journal) or an
    /// article (title provided). Attaches already-uploaded `photoURLs`; `summary` becomes
    /// the article excerpt. Returns the new post's URL (from the 201 `Location` header).
    /// Kept for **drafts** (`/api/compose` has no draft flag) and Micropub compatibility.
    @discardableResult
    public func createPost(content: String, title: String? = nil, summary: String? = nil,
                           photoURLs: [String] = [], draft: Bool = false) async throws -> URL? {
        let body = Micropub.hEntry(content: content, title: title, summary: summary,
                                   photoURLs: photoURLs, draft: draft)
        let request = try makePOST(path: "/api/micropub", body: body)
        let (_, response) = try await sendFull(request)
        return response.value(forHTTPHeaderField: "Location").flatMap(URL.init(string:))
    }

    /// `POST /api/compose` — FediHome's rich compose (`create` scope): article
    /// description, photo captions + gallery flags, video embeds, audio, crossposting,
    /// and **scheduling** (a future `scheduledFor` publishes server-side later).
    public func composePost(
        content: String,
        title: String? = nil,
        description: String? = nil,
        photos: [ComposePhoto] = [],
        videos: [ComposeVideo] = [],
        audios: [ComposeAudio] = [],
        addToPhotography: Bool = false, photoCategory: String? = nil,
        addToVideos: Bool = false, videoCategory: String? = nil,
        addToAudio: Bool = false, audioCategory: String? = nil,
        crosspostBluesky: Bool = false, crosspostThreads: Bool = false,
        scheduledFor: Date? = nil
    ) async throws -> ComposeResult {
        let body = ComposeBody.build(
            content: content, title: title, description: description,
            photos: photos, videos: videos, audios: audios,
            addToPhotography: addToPhotography, photoCategory: photoCategory,
            addToVideos: addToVideos, videoCategory: videoCategory,
            addToAudio: addToAudio, audioCategory: audioCategory,
            crosspostBluesky: crosspostBluesky, crosspostThreads: crosspostThreads,
            scheduledFor: scheduledFor
        )
        return try await postJSON("/api/compose", body: body)
    }

    // MARK: Request plumbing

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var request = URLRequest(url: try makeURL(path: path, query: query))
        request.httpMethod = "GET"
        applyDefaults(&request)
        return try decode(from: try await send(request))
    }

    private func postJSON<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        try decode(from: try await send(try makePOST(path: path, body: body)))
    }

    private func postVoid(_ path: String, body: [String: Any]) async throws {
        _ = try await send(try makePOST(path: path, body: body))
    }

    private func makePOST(path: String, body: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: try makeURL(path: path, query: []))
        request.httpMethod = "POST"
        applyDefaults(&request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func makeMultipart(path: String, fieldName: String, filename: String,
                               mimeType: String, fileData: Data) throws -> URLRequest {
        let boundary = "FediHomeBoundary-\(UUID().uuidString)"
        var request = URLRequest(url: try makeURL(path: path, query: []))
        request.httpMethod = "POST"
        applyDefaults(&request)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        // Quotes/CR/LF are legal in macOS filenames but corrupt the multipart header.
        let safeFilename = filename.map { c -> Character in
            (c == "\"" || c == "\r" || c == "\n") ? "_" : c
        }.reduce(into: "") { $0.append($1) }
        var body = Data()
        func appendString(_ string: String) { body.append(Data(string.utf8)) }
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(safeFilename)\"\r\n")
        appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        appendString("\r\n--\(boundary)--\r\n")
        request.httpBody = body
        return request
    }

    private func applyDefaults(_ request: inout URLRequest) {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
    }

    private func makeURL(path: String, query: [URLQueryItem]) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidInstanceURL
        }
        components.path = path
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw APIError.invalidInstanceURL }
        return url
    }

    /// Runs the request and maps HTTP status → `APIError`; returns the 2xx body.
    private func send(_ request: URLRequest) async throws -> Data {
        try await sendFull(request).0
    }

    /// Like `send`, but also returns the `HTTPURLResponse` (for the Micropub `Location`).
    private func sendFull(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("Non-HTTP response")
        }
        switch http.statusCode {
        case 200..<300:
            return (data, http)
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.insufficientScope(scope: Self.jsonString(data, key: "scope"))
        default:
            throw APIError.http(status: http.statusCode, body: String(data: data, encoding: .utf8))
        }
    }

    private func decode<T: Decodable>(from data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    /// Pulls a single top-level string field out of a JSON error body, best-effort.
    private static func jsonString(_ data: Data, key: String) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let value = object[key] as? String
        else { return nil }
        return value
    }
}
