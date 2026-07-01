import XCTest
@testable import FediHomeKit

final class PKCETests: XCTestCase {
    /// RFC 7636 Appendix B worked example.
    func testKnownVector() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        let expectedChallenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        XCTAssertEqual(PKCE.codeChallenge(for: verifier), expectedChallenge)
    }

    func testGeneratedPairIsConsistentAndWellFormed() {
        let pkce = PKCE()

        // The challenge must be S256(verifier).
        XCTAssertEqual(PKCE.codeChallenge(for: pkce.verifier), pkce.challenge)

        // Verifier length must sit in RFC 7636's 43...128 range.
        XCTAssertTrue((43...128).contains(pkce.verifier.count), "verifier len = \(pkce.verifier.count)")

        // Base64url charset only (no +, /, or =).
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        XCTAssertNil(pkce.verifier.unicodeScalars.first { !allowed.contains($0) })
        XCTAssertNil(pkce.challenge.unicodeScalars.first { !allowed.contains($0) })

        // state should be non-empty and effectively unique per instance.
        XCTAssertFalse(pkce.state.isEmpty)
        XCTAssertNotEqual(pkce.state, PKCE().state)
    }
}
