import SwiftUI
import FediHomeKit

struct PostRowView: View {
    let post: FediPost
    /// Instance base URL, for resolving relative media/embed paths.
    let baseURL: URL
    var actions = PostRowActions()

    @EnvironmentObject private var imageViewer: ImageViewerModel

    private var mediaItems: [FediPost.Media] { post.media(relativeTo: baseURL) }
    private var embed: FediPost.EmbedCard? { post.embedCard(relativeTo: baseURL) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if post.isBoost {
                Label("Boosted by \(post.boostedByName ?? post.boostedBy ?? "someone")",
                      systemImage: "arrow.2.squarepath")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 10) {
                AsyncAvatar(url: post.avatarURL(relativeTo: baseURL), size: 44)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(post.authorName).font(.headline).lineLimit(1)
                        Text(post.fediHandle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        Spacer(minLength: 8)
                        Text(post.publishedAt, format: .relative(presentation: .named))
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize()
                    }

                    PostContentView(post: post)

                    if !mediaItems.isEmpty { mediaView }
                    if let embed { EmbedCardView(card: embed) }

                    InteractionBar(post: post, actions: actions)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var mediaView: some View {
        let images = mediaItems.filter { $0.kind == .image }
        let rest = mediaItems.filter { $0.kind != .image }
        return VStack(alignment: .leading, spacing: 6) {
            if !images.isEmpty { imageGrid(images) }
            ForEach(rest) { item in
                switch item.kind {
                case .video: VideoPlayerView(url: item.url)
                default: LinkMediaCard(url: item.url) // .link — streaming page
                }
            }
        }
    }

    private func imageGrid(_ images: [FediPost.Media]) -> some View {
        let multiple = images.count > 1
        let urls = images.map(\.url)
        let columns = multiple ? [GridItem(.flexible()), GridItem(.flexible())] : [GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(images.enumerated()), id: \.element.id) { index, item in
                AsyncImage(url: item.url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.quaternary)
                        .overlay(ProgressView())
                }
                .frame(height: multiple ? 150 : 260)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture { imageViewer.present(urls, index: index) }
            }
        }
        .frame(maxWidth: 460)
    }
}
