import SwiftUI
import FediHomeKit

/// Identity of a person to show a profile popover for. Built from a post (clean
/// `actorUri` + `@user@domain`) or a graph person.
struct ProfileTarget: Identifiable, Equatable {
    let actorUri: String
    let username: String
    let domain: String
    let displayName: String?
    let avatarUrl: String?

    var id: String { actorUri }
    var handle: String { "@\(username)@\(domain)" }
    var name: String { (displayName?.isEmpty == false ? displayName : nil) ?? username }
    /// Human-facing profile page (most fedi servers map `@user` to the HTML profile).
    var webURL: URL? { URL(string: "https://\(domain)/@\(username)") }

    init(actorUri: String, username: String, domain: String, displayName: String?, avatarUrl: String?) {
        self.actorUri = actorUri
        self.username = username
        self.domain = domain
        self.displayName = displayName
        self.avatarUrl = avatarUrl
    }

    init(post: FediPost) {
        self.init(actorUri: post.actorUri, username: post.username, domain: post.domain,
                  displayName: post.displayName, avatarUrl: post.avatarUrl)
    }
}

/// A compact profile card (popover). Full bio/counts/posts is blocked on a FediHome
/// profile-detail endpoint (tracking issue #5); for now: identity + follow/unfollow/block/open.
struct ProfileView: View {
    let target: ProfileTarget
    let baseURL: URL

    @EnvironmentObject private var session: SessionStore
    @State private var isFollowing: Bool?
    @State private var busy = false
    @State private var confirmingBlock = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AsyncAvatar(url: MediaURL.resolve(target.avatarUrl ?? "", relativeTo: baseURL), size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(target.name).font(.headline).lineLimit(1)
                    Text(target.handle).font(.subheadline).foregroundStyle(.secondary)
                        .textSelection(.enabled).lineLimit(1)
                }
            }

            HStack(spacing: 8) {
                followButton
                Menu {
                    if let web = target.webURL { Link("Open in browser", destination: web) }
                    Button("Block…", role: .destructive) { confirmingBlock = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            if let error { Text(error).font(.caption).foregroundStyle(.red) }

            Text("Full profile (bio, posts) coming soon.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(width: 300)
        .task { await loadFollowState() }
        .confirmationDialog("Block \(target.handle)?", isPresented: $confirmingBlock, titleVisibility: .visible) {
            Button("Block", role: .destructive) { Task { await block() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Blocking unfollows them and deletes their posts + interactions from your instance. There's no unblock in the app yet.")
        }
    }

    @ViewBuilder private var followButton: some View {
        if let isFollowing, !busy {
            if isFollowing {
                Button("Unfollow") { Task { await toggleFollow(currently: true) } }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
            } else {
                Button("Follow") { Task { await toggleFollow(currently: false) } }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
        } else {
            ProgressView().controlSize(.small).frame(maxWidth: .infinity)
        }
    }

    private func loadFollowState() async {
        guard let client = session.client else { return }
        do {
            let graph = try await client.graph()
            isFollowing = graph.following.contains { $0.actorUri == target.actorUri }
        } catch {
            isFollowing = false // best-effort; still allow follow
        }
    }

    private func toggleFollow(currently: Bool) async {
        guard let client = session.client else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            if currently { try await client.unfollow(actorUri: target.actorUri) }
            else { try await client.follow(handle: target.handle) }
            isFollowing = !currently
        } catch APIError.unauthorized {
            session.reportUnauthorized()
        } catch {
            self.error = message(error)
        }
    }

    private func block() async {
        guard let client = session.client else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            try await client.block(actorUri: target.actorUri)
            isFollowing = false
        } catch APIError.unauthorized {
            session.reportUnauthorized()
        } catch {
            self.error = message(error)
        }
    }

    private func message(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
