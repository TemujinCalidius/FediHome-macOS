import Foundation

/// Every error surfaced by `FediHomeClient` and the OAuth helpers.
public enum APIError: Error, Sendable, Equatable, LocalizedError {
    /// 401 — the token is missing, invalid, or revoked. The app should prompt a reconnect.
    case unauthorized
    /// 403 `insufficient_scope` — the token lacks the scope this endpoint/action needs.
    case insufficientScope(scope: String?)
    /// A non-success HTTP status that isn't one of the above.
    case http(status: Int, body: String?)
    /// The response body didn't match the expected shape.
    case decoding(String)
    /// The request never completed (offline, DNS, TLS, timeout…).
    case transport(String)
    /// The instance URL couldn't be formed into a valid request URL.
    case invalidInstanceURL
    /// The OAuth token endpoint returned an `{ error, error_description }` body.
    case oauth(error: String, description: String?)

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Your session has expired. Please reconnect."
        case .insufficientScope(let scope):
            return scope.map { "This action needs the ‘\($0)’ permission." }
                ?? "This action needs a permission your connection doesn’t have."
        case .http(let status, _):
            return "The server responded with an unexpected error (HTTP \(status))."
        case .decoding:
            return "The server sent a response the app couldn’t read."
        case .transport(let detail):
            return "Couldn’t reach the instance: \(detail)"
        case .invalidInstanceURL:
            return "That doesn’t look like a valid instance URL."
        case .oauth(let error, let description):
            return description ?? "Authorization failed (\(error))."
        }
    }
}
