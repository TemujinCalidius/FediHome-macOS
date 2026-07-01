import Foundation
import CryptoKit

/// A PKCE (RFC 7636, S256) verifier/challenge pair plus a CSRF `state`, all
/// generated from a cryptographically-secure RNG.
public struct PKCE: Sendable, Equatable {
    public let verifier: String
    public let challenge: String
    public let state: String

    /// Fresh, random values for a new authorization request.
    public init() {
        let verifier = PKCE.randomURLSafeToken(byteCount: 64) // ~86 base64url chars (43–128 range)
        self.verifier = verifier
        self.challenge = PKCE.codeChallenge(for: verifier)
        self.state = PKCE.randomURLSafeToken(byteCount: 32)
    }

    /// Deterministic construction — used by tests and for re-deriving a challenge.
    public init(verifier: String, state: String) {
        self.verifier = verifier
        self.challenge = PKCE.codeChallenge(for: verifier)
        self.state = state
    }

    /// `BASE64URL(SHA256(verifier))`.
    public static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    /// A URL-safe random token. `SystemRandomNumberGenerator` is documented as
    /// cryptographically secure, so no `Security` import is needed.
    static func randomURLSafeToken(byteCount: Int) -> String {
        var rng = SystemRandomNumberGenerator()
        var bytes = [UInt8]()
        bytes.reserveCapacity(byteCount)
        for _ in 0..<byteCount {
            bytes.append(UInt8.random(in: UInt8.min...UInt8.max, using: &rng))
        }
        return Data(bytes).base64URLEncodedString()
    }
}

extension Data {
    /// Base64url without padding (RFC 4648 §5) — the encoding PKCE requires.
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
