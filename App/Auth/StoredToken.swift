import Foundation

/// What we persist in the Keychain per instance. Keyed by the canonical instance URL.
struct StoredToken: Codable, Equatable {
    let accessToken: String
    let scope: String
    let me: String
}
