import SwiftUI
import FediHomeKit

struct PostRowView: View {
    let post: FediPost

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if post.isBoost {
                Label("Boosted by \(post.boostedByName ?? post.boostedBy ?? "someone")",
                      systemImage: "arrow.2.squarepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 10) {
                AsyncAvatar(url: post.avatarURL, size: 44)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(post.authorName).font(.headline).lineLimit(1)
                        Text(post.fediHandle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        Spacer(minLength: 8)
                        Text(post.publishedAt, format: .relative(presentation: .named))
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize()
                    }

                    PostContentView(post: post)

                    if !post.media.isEmpty { media }

                    footer
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var media: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(post.media) { item in
                switch item.kind {
                case .image:
                    AsyncImage(url: item.url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.quaternary)
                            .frame(height: 160)
                            .overlay(ProgressView())
                    }
                    .frame(maxWidth: 440, maxHeight: 320, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                default:
                    Link(destination: item.url) {
                        Label(item.url.lastPathComponent, systemImage: "paperclip")
                    }
                    .font(.callout)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 18) {
            countLabel("heart", count: post.likeCount, active: post.likedByMe)
            countLabel("arrow.2.squarepath", count: post.boostCount, active: post.boostedByMe)
            countLabel("bubble.right", count: post.replyCount, active: false)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.top, 2)
    }

    private func countLabel(_ symbol: String, count: Int?, active: Bool) -> some View {
        Label {
            Text(count.map(String.init) ?? "–")
        } icon: {
            Image(systemName: active ? "\(symbol).fill" : symbol)
                .foregroundStyle(active ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
        }
    }
}
