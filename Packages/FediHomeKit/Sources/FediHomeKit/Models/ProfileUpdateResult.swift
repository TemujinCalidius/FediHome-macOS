import Foundation

/// Response from the `update_profile` admin action (FediHome#201) — the effective
/// runtime profile after the change (which also federates an AP actor Update).
public struct ProfileUpdateResult: Codable, Sendable, Equatable {
    public struct Profile: Codable, Sendable, Equatable {
        public let authorName: String?
        public let bio: String?
        public let tagline: String?
        public let summary: String?
        public let accentColor: String?
        public let avatar: String
        public let banner: String
    }

    public let success: Bool
    public let profile: Profile
}
