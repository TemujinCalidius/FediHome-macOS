import Foundation
import AuthenticationServices
import AppKit
import FediHomeKit

/// Raised when the owner dismisses the sign-in window — treated as a no-op, not an error.
enum AuthError: Error { case canceled }

/// Runs the interactive OAuth 2.0 + PKCE flow with `ASWebAuthenticationSession`,
/// delegating the UI-agnostic parts (discovery, URL building, token exchange) to
/// `FediHomeKit.OAuthClient`.
@MainActor
final class AuthController: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let clientID = "fedihome-macos"
    static let redirectURI = "fedihome-macos://callback"
    static let callbackScheme = "fedihome-macos"

    private let oauth = OAuthClient()
    private var activeSession: ASWebAuthenticationSession?

    func authenticate(instance: URL) async throws -> TokenResponse {
        let metadata = try await oauth.discover(instance: instance)
        let pkce = PKCE()
        let authURL = try oauth.authorizationURL(
            metadata: metadata,
            clientID: Self.clientID,
            redirectURI: Self.redirectURI,
            scopes: .firstPartyFull,
            pkce: pkce
        )

        let callback = try await presentWebAuth(url: authURL)

        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let oauthError = items.first(where: { $0.name == "error" })?.value {
            throw APIError.oauth(
                error: oauthError,
                description: items.first(where: { $0.name == "error_description" })?.value
            )
        }
        guard let returnedState = items.first(where: { $0.name == "state" })?.value,
              returnedState == pkce.state else {
            throw APIError.oauth(
                error: "state_mismatch",
                description: "The authorization response failed a security check. Please try again."
            )
        }
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw APIError.oauth(error: "invalid_response", description: "No authorization code was returned.")
        }

        return try await oauth.exchangeCode(
            metadata: metadata,
            code: code,
            verifier: pkce.verifier,
            redirectURI: Self.redirectURI,
            clientID: Self.clientID
        )
    }

    private func presentWebAuth(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Self.callbackScheme
            ) { callbackURL, error in
                if let error {
                    if let asError = error as? ASWebAuthenticationSessionError,
                       asError.code == .canceledLogin {
                        continuation.resume(throwing: AuthError.canceled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: APIError.oauth(
                        error: "no_callback",
                        description: "The sign-in window closed without completing."
                    ))
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            activeSession = session
            if !session.start() {
                continuation.resume(throwing: APIError.oauth(
                    error: "cannot_start",
                    description: "Couldn't open the sign-in window."
                ))
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }
}
