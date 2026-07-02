import SwiftUI
import FediHomeKit

/// Identity of a person to show a profile card for. Built from a post (clean
/// `actorUri` + `@user@domain`), a graph person, or a fetched `Profile`.
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

    /// From a fetched profile (`handle` is `@user@domain`).
    init(profile: Profile) {
        let parts = profile.handle.split(separator: "@", omittingEmptySubsequences: true).map(String.init)
        self.init(actorUri: profile.actorUri,
                  username: parts.first ?? profile.handle,
                  domain: parts.count > 1 ? parts[1] : "",
                  displayName: profile.displayName,
                  avatarUrl: profile.avatarUrl)
    }
}

/// A profile card: header, avatar, bio, counts (from `GET /api/profile`), and
/// follow/unfollow/block/open actions. Falls back to a lightweight identity card
/// when the profile endpoint isn't available (older instances).
struct ProfileView: View {
    let target: ProfileTarget
    let baseURL: URL
    /// Skip the fetch when the caller already resolved the profile (discovery flow).
    var prefetched: Profile?

    @EnvironmentObject private var session: SessionStore
    @State private var profile: Profile?
    @State private var bio: AttributedString?
    @State private var isFollowing: Bool?
    @State private var busy = false
    @State private var confirmingBlock = false
    @State private var didBlock = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            VStack(alignment: .leading, spacing: 12) {
                identityRow
                if let counts = profile?.counts, !(profile?.partial ?? true) {
                    countsRow(counts)
                }
                if let bio, !bio.characters.isEmpty {
                    Text(bio)
                        .font(.callout)
                        .tint(.accentColor)
                        .textSelection(.enabled)
                        .lineLimit(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
                actionsRow
                if let error { Text(error).font(.caption).foregroundStyle(.red) }
            }
            .padding(16)
        }
        .frame(width: 320)
        .task(id: target.actorUri) { await load() }
        .confirmationDialog("Block \(target.handle)?", isPresented: $confirmingBlock, titleVisibility: .visible) {
            Button("Block", role: .destructive) { Task { await block() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Blocking unfollows them and deletes their posts + interactions from your instance. You can unblock later from People → Blocked.")
        }
    }

    // MARK: Sections

    @ViewBuilder private var header: some View {
        if let headerUrl = profile?.headerUrl,
           let url = MediaURL.resolve(headerUrl, relativeTo: baseURL) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(.quaternary)
            }
            .frame(height: 90)
            .frame(maxWidth: .infinity)
            .clipped()
        }
    }

    private var identityRow: some View {
        HStack(spacing: 12) {
            AsyncAvatar(url: MediaURL.resolve(profile?.avatarUrl ?? target.avatarUrl ?? "",
                                              relativeTo: baseURL), size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile?.name ?? target.name).font(.headline).lineLimit(1)
                Text(profile?.handle ?? target.handle).font(.subheadline).foregroundStyle(.secondary)
                    .textSelection(.enabled).lineLimit(1)
                if profile?.followsMe == true {
                    Text("Follows you")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(.tint.opacity(0.15), in: Capsule())
                        .foregroundStyle(.tint)
                }
            }
        }
        .padding(.top, profile?.headerUrl != nil ? -24 : 0) // avatar overlaps the header
    }

    private func countsRow(_ counts: Profile.Counts) -> some View {
        HStack(spacing: 20) {
            countItem(counts.posts, "Posts")
            countItem(counts.following, "Following")
            countItem(counts.followers, "Followers")
            Spacer()
        }
    }

    private func countItem(_ value: Int?, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value.map(String.init) ?? "–").font(.callout.bold().monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var actionsRow: some View {
        HStack(spacing: 8) {
            followButton
            Menu {
                if let web = profile?.webURL ?? target.webURL {
                    Link("Open in browser", destination: web)
                }
                if didBlock {
                    Button("Unblock") { Task { await unblock() } }
                } else {
                    Button("Block…", role: .destructive) { confirmingBlock = true }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
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

    // MARK: Data

    private func load() async {
        if let prefetched {
            apply(prefetched)
            return
        }
        guard let client = session.client else { return }
        do {
            apply(try await client.profile(actor: target.actorUri))
        } catch APIError.unauthorized {
            session.reportUnauthorized() // expired session must trigger reconnect, not a wrong card
        } catch {
            // Older instance (no /api/profile) or fetch failure → lightweight card:
            // resolve follow state from the graph like before.
            await loadFollowStateFromGraph()
        }
    }

    private func apply(_ fetched: Profile) {
        profile = fetched
        isFollowing = fetched.followedByMe
        if let summary = fetched.summary, !summary.isEmpty {
            bio = FediHTML.attributedString(from: summary)
        }
    }

    private func loadFollowStateFromGraph() async {
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
            didBlock = true
        } catch APIError.unauthorized {
            session.reportUnauthorized()
        } catch {
            self.error = message(error)
        }
    }

    private func unblock() async {
        guard let client = session.client else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            try await client.unblock(actorUri: target.actorUri)
            didBlock = false
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
