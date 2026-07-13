import Foundation

/// Drives the token-less parts of the OAuth 2.0 + PKCE flow: discovery, building
/// the authorization URL, and exchanging the code for a token. The interactive
/// browser step (`ASWebAuthenticationSession`) lives in the app; this stays
/// UI-agnostic so iOS reuses it.
public struct OAuthClient: Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// `GET {instance}/.well-known/oauth-authorization-server`.
    public func discover(instance: URL) async throws -> OAuthMetadata {
        guard var components = URLComponents(url: instance, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidInstanceURL
        }
        components.path = "/.well-known/oauth-authorization-server"
        components.query = nil
        components.fragment = nil
        guard let url = components.url else { throw APIError.invalidInstanceURL }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

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
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(status: http.statusCode, body: String(data: data, encoding: .utf8))
        }
        do {
            return try JSONDecoder().decode(OAuthMetadata.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    /// Builds the `authorization_endpoint` URL to open in a web session.
    public func authorizationURL(
        metadata: OAuthMetadata,
        clientID: String,
        redirectURI: String,
        scopes: [FediHomeScope],
        pkce: PKCE
    ) throws -> URL {
        guard var components = URLComponents(string: metadata.authorizationEndpoint) else {
            throw APIError.invalidInstanceURL
        }
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes.spaceSeparated),
            URLQueryItem(name: "state", value: pkce.state),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        guard let url = components.url else { throw APIError.invalidInstanceURL }
        return url
    }

    /// Exchanges an authorization `code` for a bearer token (public client, PKCE).
    public func exchangeCode(
        metadata: OAuthMetadata,
        code: String,
        verifier: String,
        redirectURI: String,
        clientID: String
    ) async throws -> TokenResponse {
        guard let url = URL(string: metadata.tokenEndpoint) else { throw APIError.invalidInstanceURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = Self.formEncoded([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientID,
            "code_verifier": verifier,
        ])

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
        if (200..<300).contains(http.statusCode) {
            do {
                return try JSONDecoder().decode(TokenResponse.self, from: data)
            } catch {
                throw APIError.decoding(String(describing: error))
            }
        }
        if let oauthError = try? JSONDecoder().decode(OAuthErrorResponse.self, from: data) {
            throw APIError.oauth(error: oauthError.error, description: oauthError.errorDescription)
        }
        throw APIError.http(status: http.statusCode, body: String(data: data, encoding: .utf8))
    }

    // MARK: - Helpers

    static func formEncoded(_ fields: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let body = fields
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
        return Data(body.utf8)
    }
}
