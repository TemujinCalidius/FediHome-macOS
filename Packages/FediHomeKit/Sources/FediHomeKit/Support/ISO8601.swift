import Foundation

/// FediHome serializes dates via `Date.toISOString()`, which emits fractional
/// seconds (e.g. `2026-07-01T07:05:09.735Z`). Foundation's default `.iso8601`
/// strategy rejects the milliseconds, so we parse leniently: try the
/// fractional-seconds formatter first, then fall back to plain internet-date-time.
public enum FediDate {
    // ISO8601DateFormatter's `date(from:)` is effectively thread-safe; these are
    // read-only shared instances, so `nonisolated(unsafe)` is sound.
    nonisolated(unsafe) private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    public static func parse(_ string: String) -> Date? {
        fractional.date(from: string) ?? plain.date(from: string)
    }
}

public extension JSONDecoder.DateDecodingStrategy {
    /// Decodes ISO-8601 strings with or without fractional seconds.
    static let fediLenient = custom { decoder in
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let date = FediDate.parse(raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected ISO-8601 date, got \(raw)"
            )
        }
        return date
    }
}

public extension JSONDecoder {
    /// The decoder every FediHome response is parsed with.
    static var fediHome: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .fediLenient
        return decoder
    }
}
