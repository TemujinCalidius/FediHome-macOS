import Foundation

/// Response from `POST /api/media`. Images return just `url`; audio also returns
/// `durationSec`, `fileSize`, and `kind: "audio"`.
public struct MediaUpload: Codable, Sendable, Equatable {
    public let url: String
    public let durationSec: Int?
    public let fileSize: Int?
    public let kind: String?

    public var uploadedURL: URL? { URL(string: url) }
}
