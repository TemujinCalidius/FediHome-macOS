import XCTest
@testable import FediHomeKit

/// Regression suite built from an adversarial fan-out that hunted inputs which break
/// the HTML renderer (see Fixtures/adversarial_cases.json). Each case asserts substrings
/// the plain-text projection must / must not contain. No input may crash or hang.
final class FediHTMLAdversarialTests: XCTestCase {
    private struct Case: Decodable {
        let input: String
        let mustContain: [String]
        let mustNotContain: [String]
        let note: String
        let lens: String
    }

    func testAdversarialCases() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "adversarial_cases", withExtension: "json"))
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: url))
        XCTAssertGreaterThan(cases.count, 40, "fixture should carry the full adversarial set")

        var failures: [String] = []
        for (i, c) in cases.enumerated() {
            let output = FediHTML.plainText(from: c.input) // must never crash/hang
            for needle in c.mustContain where !Self.scalarContains(output, needle) {
                failures.append("[\(i)/\(c.lens)] expected to CONTAIN \(needle.debugDescription); got \(output.debugDescription) — \(c.note)")
            }
            for needle in c.mustNotContain where Self.scalarContains(output, needle) {
                failures.append("[\(i)/\(c.lens)] expected NOT to contain \(needle.debugDescription); got \(output.debugDescription) — \(c.note)")
            }
        }
        XCTAssertTrue(failures.isEmpty, "\n\(failures.count) adversarial failure(s):\n" + failures.joined(separator: "\n"))
    }

    /// Substring test at the Unicode-scalar level, so a stray combining mark / variation
    /// selector fusing onto an adjacent grapheme doesn't cause a false negative (the
    /// scalars are all present and in order; rendering is unaffected).
    private static func scalarContains(_ haystack: String, _ needle: String) -> Bool {
        if needle.isEmpty { return true }
        let h = Array(haystack.unicodeScalars)
        let n = Array(needle.unicodeScalars)
        guard n.count <= h.count else { return false }
        for start in 0...(h.count - n.count) where Array(h[start..<start + n.count]) == n {
            return true
        }
        return false
    }
}
