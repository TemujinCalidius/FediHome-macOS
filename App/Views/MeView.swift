import SwiftUI
import FediHomeKit

/// The owner's own profile card (from `GET /api/account`): banner, avatar, bio, and
/// follower/following/post counts, with a link to open their instance.
struct MeView: View {
    let account: Account
    let baseURL: URL

    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var bio: AttributedString?
    @State private var editing = false

    /// After an edit, `session.account` carries the refreshed profile — the `account`
    /// parameter is a snapshot from when the sheet opened.
    private var current: Account { session.account ?? account }
    private var avatarURL: URL? { MediaURL.resolve(current.avatar, relativeTo: baseURL) }
    private var bannerURL: URL? { MediaURL.resolve(current.banner, relativeTo: baseURL) }

    var body: some View {
        if editing {
            EditProfileView(account: current, baseURL: baseURL) { editing = false }
        } else {
            profileBody
        }
    }

    private var profileBody: some View {
        VStack(spacing: 0) {
            banner
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .bottom, spacing: 12) {
                        AsyncAvatar(url: avatarURL, size: 72)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(current.displayName).font(.title3).bold().lineLimit(1)
                            Text(current.fediAddress).font(.callout).foregroundStyle(.secondary)
                                .textSelection(.enabled).lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.top, -28) // pull the avatar up over the banner

                    countsRow

                    if let bio, !bio.characters.isEmpty {
                        Text(bio).tint(.accentColor).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Divider()
                    actions
                }
                .padding(20)
            }
        }
        .frame(width: 460, height: 540)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title2)
                    .foregroundStyle(.white.opacity(0.9), .black.opacity(0.35))
            }
            .buttonStyle(.plain).padding(10)
        }
        .task(id: current.summary) {
            if let summary = current.summary, !summary.isEmpty {
                bio = FediHTML.attributedString(from: summary)
            } else {
                bio = nil
            }
        }
    }

    private var banner: some View {
        AsyncImage(url: bannerURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Rectangle().fill(LinearGradient(colors: [.accentColor.opacity(0.5), .accentColor.opacity(0.2)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var countsRow: some View {
        HStack(spacing: 28) {
            countItem(current.counts.posts, "Posts")
            countItem(current.counts.following, "Following")
            countItem(current.counts.followers, "Followers")
            Spacer()
        }
    }

    private func countItem(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(value)").font(.headline.monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var actions: some View {
        HStack {
            Button { editing = true } label: { Label("Edit Profile", systemImage: "pencil") }
            Button { openURL(baseURL) } label: { Label("Open my site", systemImage: "safari") }
            Spacer()
            Button("Disconnect", role: .destructive) { session.disconnect(); dismiss() }
        }
    }
}
