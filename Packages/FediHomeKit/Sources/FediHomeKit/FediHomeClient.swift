import Foundation

/// The authenticated read client for a single FediHome instance. Holds the base
/// URL + bearer token and exposes typed calls for the read API. An `actor` so it's
/// safe to share across the app; UI-agnostic so iOS reuses it verbatim.
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

    // MARK: Request plumbing

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        let url = try makeURL(path: path, query: query)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(request)
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

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
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
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decoding(String(describing: error))
            }
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.insufficientScope(scope: Self.jsonString(data, key: "scope"))
        default:
            throw APIError.http(status: http.statusCode, body: String(data: data, encoding: .utf8))
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
