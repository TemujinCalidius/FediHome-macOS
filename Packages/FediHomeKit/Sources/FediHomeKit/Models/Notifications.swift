import Foundation

/// One entry in the notifications bell (`GET /api/notifications`).
public struct NotificationItem: Codable, Sendable, Identifiable, Equatable {
    public enum Kind: Sendable, Equatable, Codable {
        case like, boost, reply, follow, comment, dm, update
        case unknown(String)

        public init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            switch raw {
            case "like": self = .like
            case "boost": self = .boost
            case "reply": self = .reply
            case "follow": self = .follow
            case "comment": self = .comment
            case "dm": self = .dm
            case "update": self = .update
            default: self = .unknown(raw)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }

        public var rawValue: String {
            switch self {
            case .like: return "like"
            case .boost: return "boost"
            case .reply: return "reply"
            case .follow: return "follow"
            case .comment: return "comment"
            case .dm: return "dm"
            case .update: return "update"
            case .unknown(let raw): return raw
            }
        }
    }

    public let id: String
    public let type: Kind
    public let source: String
    public let actor: String
    public let actorUrl: String?
    public let avatarUrl: String?
    public let summary: String
    public let targetUrl: String?
    public let maintenanceId: String?
    public let createdAt: Date

    public var avatarURL: URL? { avatarUrl.flatMap(URL.init(string:)) }
}

/// `GET /api/notifications` — the bell payload.
public struct NotificationsResponse: Codable, Sendable, Equatable {
    public let count: Int
    public let items: [NotificationItem]
    public let categoryCounts: [String: Int]
}
