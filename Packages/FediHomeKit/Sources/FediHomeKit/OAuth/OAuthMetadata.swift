import Foundation

/// RFC 8414 authorization-server metadata from
/// `GET /.well-known/oauth-authorization-server`.
public struct OAuthMetadata: Codable, Sendable, Equatable {
    public let issuer: String
    public let authorizationEndpoint: String
    public let tokenEndpoint: String
    public let revocationEndpoint: String?
    public let scopesSupported: [String]?
    public let codeChallengeMethodsSupported: [String]?

    enum CodingKeys: String, CodingKey {
        case issuer
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case revocationEndpoint = "revocation_endpoint"
        case scopesSupported = "scopes_supported"
        case codeChallengeMethodsSupported = "code_challenge_methods_supported"
    }
}

/// The `POST /api/oauth/token` success body.
public struct TokenResponse: Codable, Sendable, Equatable {
    public let accessToken: String
    public let tokenType: String
    public let scope: String
    /// The canonical instance URL the token belongs to.
    public let me: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case me
    }
}

/// The OAuth error body (`{ error, error_description }`).
struct OAuthErrorResponse: Decodable {
    let error: String
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}
