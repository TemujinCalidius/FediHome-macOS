import Foundation

/// `GET /api/micropub?q=source&url=` — a post's editable source (Micropub h-entry).
/// Note: FediHome's source response carries **no media properties**; combined with
/// `/api/compose`'s opt-in media edits, that means text-only edits leave a post's
/// photos/video/audio untouched.
public struct PostSource: Codable, Sendable, Equatable {
    public struct Properties: Codable, Sendable, Equatable {
        public let name: [String]?
        public let content: [String]?
        public let summary: [String]?
        public let postStatus: [String]?

        enum CodingKeys: String, CodingKey {
            case name, content, summary
            case postStatus = "post-status"
        }
    }

    public let properties: Properties

    public var title: String? { properties.name?.first }
    public var content: String { properties.content?.first ?? "" }
    public var summary: String? { properties.summary?.first }
    public var isDraft: Bool { properties.postStatus?.first == "draft" }
}
