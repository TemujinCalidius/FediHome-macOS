import Foundation

/// The OAuth scopes a FediHome instance recognizes. A first-party client
/// requests the full set so posting/interacting later needs no re-auth.
public enum FediHomeScope: String, Sendable, CaseIterable, Codable {
    case read
    case create
    case update
    case delete
    case media
    case interact
    case dm
    case manage
}

public extension Array where Element == FediHomeScope {
    /// The full first-party scope set, space-separated for the `scope` param.
    static var firstPartyFull: [FediHomeScope] { FediHomeScope.allCases }

    var spaceSeparated: String {
        map(\.rawValue).joined(separator: " ")
    }
}
