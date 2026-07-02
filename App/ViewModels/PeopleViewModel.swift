import Foundation
import FediHomeKit

@MainActor
final class PeopleViewModel: ObservableObject {
    @Published private(set) var graph: SocialGraph?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    @Published var followHandle = ""
    @Published private(set) var isFollowing = false
    @Published var actionMessage: String?
    /// Resolved profile from the lookup field — shown as a discovery card.
    @Published var discovered: Profile?

    func load(session: SessionStore) async {
        guard let client = session.client else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            graph = try await client.graph()
        } catch APIError.unauthorized {
            session.reportUnauthorized()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// Resolve a handle to a profile (discovery card with a Follow button). Falls back
    /// to a direct follow on older instances without `/api/profile`.
    func lookup(session: SessionStore) async {
        guard let client = session.client else { return }
        guard let handle = Self.normalizedHandle(followHandle) else {
            actionMessage = "Enter a handle like @name@server.social"
            return
        }
        isFollowing = true
        actionMessage = nil
        defer { isFollowing = false }
        do {
            discovered = try await client.profile(handle: handle)
            followHandle = ""
        } catch APIError.unauthorized {
            session.reportUnauthorized()
        } catch APIError.http(let status, _) where status == 404 {
            await follow(session: session) // older instance — follow directly
        } catch {
            actionMessage = Self.message(for: error)
        }
    }

    func follow(session: SessionStore) async {
        guard let client = session.client else { return }
        guard let handle = Self.normalizedHandle(followHandle) else {
            actionMessage = "Enter a handle like @name@server.social"
            return
        }
        isFollowing = true
        actionMessage = nil
        defer { isFollowing = false }
        do {
            try await client.follow(handle: handle)
            actionMessage = "Followed \(handle)"
            followHandle = ""
            await load(session: session) // refresh Following
        } catch APIError.unauthorized {
            session.reportUnauthorized()
        } catch {
            actionMessage = Self.message(for: error)
        }
    }

    /// Unblocks and refreshes the graph so the Blocked list updates.
    func unblock(_ person: BlockedPerson, session: SessionStore) async {
        guard let client = session.client else { return }
        do {
            try await client.unblock(actorUri: person.actorUri)
            await load(session: session)
        } catch APIError.unauthorized {
            session.reportUnauthorized()
        } catch {
            actionMessage = Self.message(for: error)
        }
    }

    /// Normalizes `name@server` / `@name@server` → `@name@server`; nil if it isn't a handle.
    static func normalizedHandle(_ raw: String) -> String? {
        var handle = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if handle.hasPrefix("@") { handle.removeFirst() }
        let parts = handle.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[1].contains(".") else { return nil }
        return "@\(handle)"
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
