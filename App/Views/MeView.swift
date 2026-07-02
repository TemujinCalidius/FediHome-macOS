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

    private var avatarURL: URL? { MediaURL.resolve(account.avatar, relativeTo: baseURL) }
    private var bannerURL: URL? { MediaURL.resolve(account.banner, relativeTo: baseURL) }

    var body: some View {
        VStack(spacing: 0) {
            banner
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .bottom, spacing: 12) {
                        AsyncAvatar(url: avatarURL, size: 72)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.displayName).font(.title3).bold().lineLimit(1)
                            Text(account.fediAddress).font(.callout).foregroundStyle(.secondary)
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
        .task {
            if let summary = account.summary, !summary.isEmpty {
                bio = FediHTML.attributedString(from: summary)
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
            countItem(account.counts.posts, "Posts")
            countItem(account.counts.following, "Following")
            countItem(account.counts.followers, "Followers")
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
            Button { openURL(baseURL) } label: { Label("Open my site", systemImage: "safari") }
            Spacer()
            Button("Disconnect", role: .destructive) { session.disconnect(); dismiss() }
        }
    }
}
